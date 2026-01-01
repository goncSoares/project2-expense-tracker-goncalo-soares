# 📱 Expense Tracker — Flutter App

**Autor:** Gonçalo Soares  
**Número:** a22306242

Aplicação móvel para gestão de despesas, com sincronização em tempo real, estatísticas e conversão automática de moeda através de API externa.

---

## 🌐 Integração com API Externa
A app utiliza a **Frankfurter API** para converter valores de **EUR → USD** ao visualizar os detalhes de uma despesa.  
É gratuita, não requer autenticação e fornece dados fiáveis do Banco Central Europeu.  
Se a API falhar, o valor original em euros é mantido.

---

## 🏠 Home Screen
Ecrã principal para **visualização e gestão de todas as despesas**.

### **Principais Funcionalidades**
- Lista de despesas com **categoria**, **descrição**, **valor (€)** e **data**.
- Card com **total filtrado**.
- **Filtros por categoria** (8 opções) e **intervalo de datas**.
- Acesso rápido ao ecrã de estatísticas.
- **Adicionar**, **editar** e **eliminar** despesas (com swipe e confirmação).
- **Sincronização em tempo real** com Firestore.
- Mensagem de *empty state* quando não existem dados.

---

## 📝 Expense Form Screen (Adicionar/Editar)
Formulário para criar ou editar despesas.

### **Principais Funcionalidades**
- Modo automático **Adicionar / Editar**.
- Campos: categoria, descrição, valor (€), data.
- **Validação completa** (descrição ≥ 3 caracteres, valor > 0, data válida).
- Indicador de carregamento ao guardar.
- **Feedback visual** (SnackBars de sucesso/erro).
- Autofill dos campos em modo edição.
- Botão dinâmico: *Add Expense* / *Update Expense*.

---

## 📄 Expense Detail Screen
Ecrã de detalhes com conversão de moeda integrada.

### **Principais Funcionalidades**
- Card com categoria, descrição, data e valor em €.
- Secção de **conversão EUR → USD** com loading e gestão de erros.
- Valor convertido apresentado em **USD ($)**.
- Botão de edição no AppBar.
- Layout limpo e responsivo.

---

## 📊 Statistics Screen
Análise gráfica dos padrões de consumo.

### **Principais Funcionalidades**
- Seleção de período: **This Week**, **This Month**, **This Year**.
- Card com total gasto e número de transações.
- **Gráfico de linha** (Custom Painter) com tendência diária animada.
- Cálculo da **média diária**.
- Distribuição por categoria com barras de progresso e percentagens.
- *Empty state* quando não existem despesas no período.
