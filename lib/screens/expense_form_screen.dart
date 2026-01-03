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
import 'location_detail_screen.dart';

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
  String? _locationName;

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
      _locationName = widget.expense!.locationName;

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
          _receiptUrl = null;
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
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final position = await _locationService.getCurrentLocation();

      if (position != null) {
        setState(() {
          _currentLocation = position;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location saved!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get location'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _openLocationDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationDetailScreen(
          latitude: _currentLocation?.latitude,
          longitude: _currentLocation?.longitude,
          locationName: _locationName,
          onLocationUpdated: (lat, lng, name) {
            setState(() {
              _currentLocation = Position(
                latitude: lat,
                longitude: lng,
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                altitudeAccuracy: 0,
                heading: 0,
                headingAccuracy: 0,
                speed: 0,
                speedAccuracy: 0,
              );
              _locationName = name;
            });
          },
        ),
      ),
    );
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

        // Upload receipt LOCALLY if new image selected
        if (_receiptImage != null) {
          final tempExpenseId = widget.expense?.id ??
              DateTime.now().millisecondsSinceEpoch.toString();

          uploadedReceiptUrl = await _storageService.uploadItemImage(
            tempExpenseId,
            _receiptImage!,
            onProgress: (progress) {
              setState(() => _uploadProgress = progress);
            },
          );

          if (uploadedReceiptUrl == null) {
            throw Exception('Failed to save receipt');
          }
        }

        // Create expense
        final expense = Expense(
          id: widget.expense?.id ?? '',
          category: _selectedCategory!,
          description: _descriptionController.text.trim(),
          amount: double.parse(
            _amountController.text.replaceAll(RegExp(r'[^\d.]'), ''),
          ),
          date: _selectedDate,
          receiptUrl: uploadedReceiptUrl,
          latitude: _currentLocation?.latitude,
          longitude: _currentLocation?.longitude,
          locationName: _locationName,
        );

        // Save
        if (widget.expense == null) {
          await provider.addExpense(expense);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense added!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          await provider.updateExpense(expense);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense updated!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }

        if (mounted) Navigator.pop(context);
      } catch (e) {
        print('Save error: $e');
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
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
      ),
      body: _isLoading && _uploadProgress > 0
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Uploading: ${(_uploadProgress * 100).toInt()}%'),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
                validator: (value) =>
                value == null ? 'Select category' : null,
              ),
              const SizedBox(height: 16),

              // Description
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
                    return 'Enter description';
                  }
                  if (value.trim().length < 3) {
                    return 'Min 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount
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
                    return 'Enter amount';
                  }
                  final amount = double.tryParse(
                      value.replaceAll(RegExp(r'[^\d.]'), ''));
                  if (amount == null || amount <= 0) {
                    return 'Enter valid amount > 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date
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
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Location Section (IMPROVED!)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on),
                          SizedBox(width: 8),
                          Text(
                            'Location (Optional)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_currentLocation != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Location saved',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _currentLocation = null;
                                        _locationName = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (_locationName != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _locationName!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                '${_currentLocation!.latitude.toStringAsFixed(6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _openLocationDetails,
                                icon: const Icon(Icons.map),
                                label: const Text('View/Edit on Map'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          'No location',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                _isLoading ? null : _getCurrentLocation,
                                icon: const Icon(Icons.my_location),
                                label: const Text('Get Location'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Receipt Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.receipt),
                          SizedBox(width: 8),
                          Text(
                            'Receipt (Optional)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: _receiptImage != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_receiptImage!,
                                fit: BoxFit.cover),
                          )
                              : _receiptUrl != null
                              ? ClipRRect(
                            borderRadius:
                            BorderRadius.circular(12),
                            child: Image.file(
                              File(_receiptUrl!),
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) {
                                return Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image,
                                        size: 40,
                                        color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text('Image not found',
                                        style: TextStyle(
                                            color:
                                            Colors.grey[600])),
                                  ],
                                );
                              },
                            ),
                          )
                              : Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  size: 40,
                                  color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text('Tap to add photo',
                                  style: TextStyle(
                                      color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showImageSourceDialog,
                        icon: const Icon(Icons.camera_alt),
                        label: Text(_receiptImage != null ||
                            _receiptUrl != null
                            ? 'Change'
                            : 'Add Photo'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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