import SwiftUI

struct EditReceiptView: View {
    let originalReceipt: ReceiptSnapshot
    let availableCategories: [CategorySnapshot]
    let onSave: (ReceiptSnapshot) -> Void
    let onCancel: () -> Void

    @State private var storeName: String
    @State private var currency: String
    @State private var date: Date
    @State private var selectedCategoryId: String?
    @State private var paymentMethod: String
    @State private var transactionId: String
    @State private var editableItems: [EditableItemDraft]

    init(
        originalReceipt: ReceiptSnapshot,
        availableCategories: [CategorySnapshot],
        onSave: @escaping (ReceiptSnapshot) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.originalReceipt = originalReceipt
        self.availableCategories = availableCategories
        self.onSave = onSave
        self.onCancel = onCancel

        _storeName = State(initialValue: originalReceipt.storeName)
        _currency = State(initialValue: originalReceipt.currency)
        _date = State(initialValue: originalReceipt.dateTimestamp)
        _selectedCategoryId = State(initialValue: originalReceipt.category?.id)
        _paymentMethod = State(initialValue: originalReceipt.metadata.paymentMethod ?? "")
        _transactionId = State(initialValue: originalReceipt.metadata.transactionId ?? "")
        _editableItems = State(initialValue: originalReceipt.items.map(EditableItemDraft.init(snapshot:)))
    }

    private var calculatedTotal: Double {
        editableItems.reduce(0.0) { $0 + $1.parsedPrice }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("General Info") {
                    TextField("Store Name", text: $storeName)
                        .textInputAutocapitalization(.words)

                    DatePicker(
                        "Date & Time",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Picker("Category", selection: $selectedCategoryId) {
                        Text("Uncategorized").tag(String?.none)
                        ForEach(availableCategories) { category in
                            Label(category.name, systemImage: IconRegistry.symbolName(for: category.iconId))
                                .tag(Optional(category.id))
                        }
                    }

                    HStack {
                        Text("Currency")
                        Spacer()
                        TextField("EUR", text: $currency)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                    }

                    HStack {
                        Text("Total")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(CurrencyUtils.format(calculatedTotal, currencyCode: currency))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                }

                Section("Metadata") {
                    TextField("Payment Method (optional)", text: $paymentMethod)
                    TextField("Transaction ID (optional)", text: $transactionId)
                        .autocorrectionDisabled()
                }

                Section {
                    ForEach($editableItems) { $draft in
                        VStack(spacing: 10) {
                            HStack {
                                TextField("Item Name", text: $draft.name)
                                    .font(.body.weight(.medium))

                                Button(role: .destructive) {
                                    removeItem(id: draft.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove item")
                            }

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Qty")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    TextField("1", text: $draft.quantityText)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                                .frame(maxWidth: 80)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unit")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    TextField("pcs", text: $draft.unit)
                                        .textFieldStyle(.roundedBorder)
                                }
                                .frame(maxWidth: 80)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Price (\(currency.uppercased()))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    TextField("0.00", text: $draft.priceText)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        editableItems.remove(atOffsets: offsets)
                    }

                    Button {
                        editableItems.append(
                            EditableItemDraft(
                                id: UUID().uuidString,
                                name: "",
                                quantityText: "1",
                                unit: "",
                                priceText: ""
                            )
                        )
                    } label: {
                        Label("Add Item", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Items")
                } footer: {
                    Text("Total amount is automatically calculated from the sum of item prices.")
                }
            }
            .navigationTitle("Edit Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Label("Cancel", systemImage: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveChanges) {
                        Label("Save", systemImage: "checkmark")
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func removeItem(id: String) {
        editableItems.removeAll { $0.id == id }
    }

    private func saveChanges() {
        let matchedCategory = availableCategories.first { $0.id == selectedCategoryId }
        let sanitizedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let finalCurrency = sanitizedCurrency.isEmpty ? originalReceipt.currency : sanitizedCurrency

        let paymentTrimmed = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        let txTrimmed = transactionId.trimmingCharacters(in: .whitespacesAndNewlines)

        let updatedItems = editableItems.map { draft in
            ReceiptItemSnapshot(
                id: draft.id,
                name: draft.name,
                quantity: draft.parsedQuantity,
                unit: draft.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.unit,
                price: draft.parsedPrice
            )
        }

        let updated = ReceiptSnapshot(
            id: originalReceipt.id,
            storeName: storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? originalReceipt.storeName
                : storeName,
            totalAmount: calculatedTotal,
            dateTimestamp: date,
            currency: finalCurrency,
            imageFileName: originalReceipt.imageFileName,
            metadata: ReceiptMetadataSnapshot(
                paymentMethod: paymentTrimmed.isEmpty ? nil : paymentTrimmed,
                transactionId: txTrimmed.isEmpty ? nil : txTrimmed
            ),
            category: matchedCategory,
            items: updatedItems
        )

        onSave(updated)
    }
}

private struct EditableItemDraft: Identifiable {
    let id: String
    var name: String
    var quantityText: String
    var unit: String
    var priceText: String

    init(id: String, name: String, quantityText: String, unit: String, priceText: String) {
        self.id = id
        self.name = name
        self.quantityText = quantityText
        self.unit = unit
        self.priceText = priceText
    }

    init(snapshot: ReceiptItemSnapshot) {
        self.id = snapshot.id
        self.name = snapshot.name
        if snapshot.quantity == 0 {
            self.quantityText = ""
        } else if snapshot.quantity.truncatingRemainder(dividingBy: 1) == 0 {
            self.quantityText = "\(Int(snapshot.quantity))"
        } else {
            self.quantityText = String(snapshot.quantity)
        }
        self.unit = snapshot.unit ?? ""
        if snapshot.price == 0 {
            self.priceText = ""
        } else {
            self.priceText = String(format: "%.2f", snapshot.price)
        }
    }

    var parsedQuantity: Double {
        let normalized = quantityText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0.0
    }

    var parsedPrice: Double {
        let normalized = priceText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0.0
    }
}
