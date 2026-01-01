import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../services/image_service.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense;
  const ExpenseFormScreen({super.key, this.expense});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final ImageService _imageService = ImageService();
  final StorageService _storageService = StorageService();
  final LocationService _locationService = LocationService();

  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  File? _receiptImage;
  String? _receiptUrl;
  Position? _currentLocation;

  final List<String> _categories = [
    'Food',
    'Transport',
    'Entertainment',
    'Shopping',
    'Health',
    'Education',
    'Bills',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _selectedCategory = widget.expense!.category;
      _descriptionController.text = widget.expense!.description;
      _amountController.text = widget.expense!.amount.toString();
      _selectedDate = widget.expense!.date;
      _receiptUrl = widget.expense!.receiptUrl;

      // Load existing location if available
      if (widget.expense!.latitude != null && widget.expense!.longitude != null) {
        _currentLocation = Position(
          latitude: widget.expense!.latitude!,
          longitude: widget.expense!.longitude!,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickReceiptImage(useCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickReceiptImage(useCamera: false);
              },
            ),
            if (_receiptImage != null || _receiptUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Receipt'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _receiptImage = null;
                    _receiptUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReceiptImage({required bool useCamera}) async {
    try {
      File? imageFile;
      if (useCamera) {
        imageFile = await _imageService.pickImageFromCamera();
      } else {
        imageFile = await _imageService.pickImageFromGallery();
      }

      if (imageFile != null) {
        setState(() {
          _receiptImage = imageFile;
          _receiptUrl = null; // Clear old URL if picking new image
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      print('Button pressed - getting location...');

      final position = await _locationService.getCurrentLocation();

      if (position != null) {
        print('Location received: ${position.latitude}, ${position.longitude}');
        setState(() {
          _currentLocation = position;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location saved!\n${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get location'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Location error: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        // Show error dialog with options
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              if (e.toString().contains('disabled'))
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _locationService.openLocationSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              if (e.toString().contains('permanently denied'))
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _locationService.openAppSettings();
                  },
                  child: const Text('Open App Settings'),
                ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _uploadProgress = 0.0;
      });

      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      try {
        String? uploadedReceiptUrl = _receiptUrl;

        // Upload receipt image if user picked a new one
        if (_receiptImage != null) {
          print('Starting receipt upload...');

          // Generate temporary expense ID for upload
          final tempExpenseId = widget.expense?.id ??
              DateTime.now().millisecondsSinceEpoch.toString();

          print('Expense ID for upload: $tempExpenseId');

          // Upload with progress tracking
          uploadedReceiptUrl = await _storageService.uploadReceiptImage(
            expenseId: tempExpenseId,
            imageFile: _receiptImage!,
            onProgress: (progress) {
              print('Upload progress: ${(progress * 100).toInt()}%');
              setState(() {
                _uploadProgress = progress;
              });
            },
          );

          if (uploadedReceiptUrl == null) {
            throw Exception('Failed to upload receipt image');
          }

          print('Receipt uploaded successfully: $uploadedReceiptUrl');
        }

        // Create expense object
        final expense = Expense(
          id: widget.expense?.id ?? '',
          category: _selectedCategory!,
          description: _descriptionController.text.trim(),
          amount: double.parse(
            _amountController.text.replaceAll(RegExp(r'[^\d.]'), ''),
          ),
          date: _selectedDate,
          receiptUrl: uploadedReceiptUrl,
          latitude: _currentLocation?.latitude,   // ← NOVO!
          longitude: _currentLocation?.longitude, // ← NOVO!
        );

        print('Expense object created: ${expense.toFirestore()}');

        // Save to Firestore
        if (widget.expense == null) {
          print('Adding new expense...');
          await provider.addExpense(expense);
          print('Expense added successfully');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense added successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          print('Updating existing expense...');
          await provider.updateExpense(expense);
          print('Expense updated successfully');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }

        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            if (_uploadProgress > 0 && _uploadProgress < 1)
              Column(
                children: [
                  Text(
                    'Uploading: ${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                    ),
                  ),
                ],
              ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) =>
                value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  if (value.trim().length < 3) {
                    return 'Description must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount Field
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (€)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.euro),
                ),
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(
                    value.replaceAll(RegExp(r'[^\d.]'), ''),
                  );
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Location Section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on),
                          const SizedBox(width: 8),
                          const Text(
                            'Location (Optional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_currentLocation != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}\n'
                                      'Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setState(() => _currentLocation = null);
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'No location attached',
                          style: TextStyle(color: Colors.grey[600]),
                        ),

                      const SizedBox(height: 8),

                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.my_location),
                          label: Text(
                            _currentLocation == null
                                ? 'Get Current Location'
                                : 'Update Location',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Receipt Image Section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt),
                          const SizedBox(width: 8),
                          const Text(
                            'Receipt Image (Optional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Image Preview
                      Center(
                        child: GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child: _receiptImage != null
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _receiptImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                                : _receiptUrl != null
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _receiptUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.error,
                                      color: Colors.red,
                                    ),
                                  );
                                },
                              ),
                            )
                                : Center(
                              child: Column(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add Receipt Photo',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Center(
                        child: TextButton.icon(
                          onPressed: _showImageSourceDialog,
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                            _receiptImage != null || _receiptUrl != null
                                ? 'Change Photo'
                                : 'Add Photo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  widget.expense == null
                      ? 'Add Expense'
                      : 'Update Expense',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}