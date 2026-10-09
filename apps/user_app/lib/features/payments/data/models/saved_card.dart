/// Mirrors backend's SavedCardController.SavedCardResponse: brand and last four
/// digits only — the app never sees a full card number.
class SavedCard {
  final String id;
  final String? brand;
  final String? last4;

  const SavedCard({required this.id, this.brand, this.last4});

  factory SavedCard.fromJson(Map<String, dynamic> json) =>
      SavedCard(id: json['id'] as String, brand: json['brand'] as String?, last4: json['last4'] as String?);
}

/// Mirrors backend's SavedCardController.SavedCardsResponse.
class SavedCards {
  final List<SavedCard> cards;

  /// The next online payment also saves the card that is used.
  final bool saveOnNextPayment;

  /// A saved card can be charged right away. False: cards are kept, but
  /// payments still go through the provider's payment page.
  final bool canPayWithSavedCard;

  const SavedCards({required this.cards, required this.saveOnNextPayment, required this.canPayWithSavedCard});

  static const empty = SavedCards(cards: [], saveOnNextPayment: false, canPayWithSavedCard: false);

  /// Cards the customer can choose between when paying.
  List<SavedCard> get usable => canPayWithSavedCard ? cards : const [];

  factory SavedCards.fromJson(Map<String, dynamic> json) => SavedCards(
    cards: (json['cards'] as List<dynamic>)
        .map((e) => SavedCard.fromJson(e as Map<String, dynamic>))
        .toList(),
    saveOnNextPayment: json['saveOnNextPayment'] as bool? ?? false,
    canPayWithSavedCard: json['canPayWithSavedCard'] as bool? ?? false,
  );
}
