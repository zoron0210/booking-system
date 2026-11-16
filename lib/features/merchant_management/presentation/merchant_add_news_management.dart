part of 'merchant_add_page.dart';

extension _MerchantAddNewsManagement on MerchantAddPageState {
  Widget _addSectionTabs() => SegmentedButton<String>(
    key: const ValueKey('merchant-add-section-tabs'),
    segments: const [
      ButtonSegment(
        value: 'Booking cards',
        label: AppText('Booking cards', localize: true),
      ),
      ButtonSegment(
        value: 'News cards',
        label: AppText('News cards', localize: true),
      ),
    ],
    selected: {_selectedAddSection},
    onSelectionChanged: (value) {
      _updateAddPageState(() => _selectedAddSection = value.first);
    },
  );

  Future<void> _openNewsFormForBusiness(Map<String, dynamic> business) async {
    final id = _businessId(business);
    if (id == null) return;
    await _openNewsForm({'businessId': id, '_incomplete': true});
  }

  Future<void> _openNewsForm([Map<String, dynamic>? editing]) async {
    final isIncomplete = editing?['_incomplete'] == true;
    final body = TextEditingController(
      text: isIncomplete ? '' : '${editing?['body'] ?? ''}',
    );
    var businessId = _id(editing?['businessId']);
    final initialBusiness = widget.businesses.firstWhere(
      (item) => _businessId(item) == businessId,
      orElse: () => <String, dynamic>{},
    );
    var newsImages = _businessImageUrls(initialBusiness);
    final formKey = GlobalKey<FormState>();
    final businessFieldKey = GlobalKey();
    final newsBodyFieldKey = GlobalKey();
    String? imageValidationMessage;
    StateSetter? setDialogState;
    final selected = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: AppText(
          isIncomplete
              ? 'Complete news card'
              : editing == null
              ? 'Create news card'
              : 'Edit news card',
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .68,
          ),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                setDialogState = setState;
                return Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        key: businessFieldKey,
                        initialValue: businessId,
                        decoration: InputDecoration(
                          labelText: appLanguageText(
                            'Booking card',
                            'Booking card',
                          ),
                        ),
                        items: [
                          for (final business in widget.businesses)
                            DropdownMenuItem(
                              value: _businessId(business),
                              child: AppText(
                                '${business['name'] ?? 'Business'}',
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          businessId = value;
                          if (editing == null ||
                              _postBusinessId(editing) != value) {
                            final selectedBusiness = widget.businesses
                                .firstWhere(
                                  (item) => _businessId(item) == value,
                                  orElse: () => <String, dynamic>{},
                                );
                            newsImages = _businessImageUrls(selectedBusiness);
                            imageValidationMessage = null;
                          }
                        }),
                        validator: (value) =>
                            value == null ? 'Choose a booking card.' : null,
                      ),
                      if (businessId != null)
                        _newsVenuePreview(businessId!, body.text, newsImages),
                      if (imageValidationMessage != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: AppText(
                              imageValidationMessage!,
                              style: const TextStyle(color: Colors.red),
                              localize: true,
                            ),
                          ),
                        ),
                      TextFormField(
                        key: newsBodyFieldKey,
                        controller: body,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: appLanguageText(
                            'Short venue news',
                            'Short venue news',
                          ),
                          hintText: appLanguageText(
                            'Add a short update about this venue',
                            'Add a short update about this venue',
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a short venue update.'
                            : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AppText('Cancel', localize: true),
          ),
          FilledButton(
            onPressed: () {
              if (newsImages.isEmpty) {
                setDialogState?.call(
                  () => imageValidationMessage = 'Add a venue image by editing its Booking Card before saving this News Card.',
                );
                return;
              }
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
                return;
              }
              final target = businessId == null
                  ? businessFieldKey.currentContext
                  : newsBodyFieldKey.currentContext;
              if (target != null) {
                Scrollable.ensureVisible(
                  target,
                  duration: const Duration(milliseconds: 250),
                  alignment: .15,
                );
              }
            },
            child: const AppText('Save', localize: true),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final savedBusinessId = businessId;
    final selectedImages = newsImages;
    if (selected != true ||
        savedBusinessId == null ||
        body.text.trim().isEmpty) {
      body.dispose();
      return;
    }
    if (selectedImages.isEmpty) {
      body.dispose();
      _showNewsCardMessage(
        'Add a venue image by editing its Booking Card before saving this News Card.',
      );
      return;
    }
    String? token;
    try {
      token = await _session.loadApiToken();
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Please sign in again.', 401);
      }
    } on Exception catch (error) {
      body.dispose();
      _showNewsCardMessage('Could not save News Card: $error');
      return;
    }
    final business = widget.businesses.firstWhere(
      (item) => _businessId(item) == businessId,
      orElse: () => <String, dynamic>{},
    );
    final venueName = '${business['name'] ?? 'Venue'}';
    final statusName = editing?['status'] as String? ?? 'published';
    final payload = MerchantNewsPostDraft(
      businessId: businessId,
      title: editing?['title'] as String? ?? '$venueName update',
      body: body.text.trim(),
      imageUrl: selectedImages.first,
      status: NewsPostStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => NewsPostStatus.published,
      ),
    );
    try {
      if (editing == null || isIncomplete) {
        await _api.venues.createMerchantNewsPost(token: token, post: payload);
      } else {
        await _api.venues.updateMerchantNewsPost(
          token: token,
          id: _id(editing['id'])!,
          post: payload,
        );
      }
      await widget.onBusinessesChanged();
      await _loadNewsPosts(force: true);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText('$error')));
      }
    } finally {
      body.dispose();
    }
  }

  Widget _newsVenuePreview(
    int businessId,
    String newsText,
    List<String> images,
  ) {
    final business = widget.businesses.firstWhere(
      (item) => _businessId(item) == businessId,
      orElse: () => <String, dynamic>{},
    );
    final name = '${business['name'] ?? 'Venue'}';
    final type = '${business['businessType'] ?? 'Booking'}';
    final category = '${business['category'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppText(
              'News Feed preview',
              style: TextStyle(
                color: _addMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
              localize: true,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _addLine),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: const AppText(
                    'News Feed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                    localize: true,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 170,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (images.isEmpty)
                        ColoredBox(
                          color: AppColors.softOrange,
                          child: Icon(
                            Icons.storefront_rounded,
                            size: 48,
                            color: _addOrange,
                          ),
                        )
                      else ...[
                        Builder(
                          builder: (context) {
                            final provider = _safeImageProvider(images.first);
                            return provider == null
                                ? ColoredBox(
                                    color: AppColors.softOrange,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 42,
                                      color: _addOrange,
                                    ),
                                  )
                                : Image(
                                    key: ValueKey(
                                      'news-card-image-preview-$businessId',
                                    ),
                                    image: provider,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => ColoredBox(
                                      color: AppColors.softOrange,
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 42,
                                        color: _addOrange,
                                      ),
                                    ),
                                  );
                          },
                        ),
                        if (images.length > 1)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .65),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                child: AppText(
                                  '${images.length} venue photos',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _addInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (images.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: AppText(
                            'Add venue photos by editing the Booking Card.',
                            localize: true,
                          ),
                        ),
                      const SizedBox(height: 6),
                      AppText(
                        category.isEmpty ? type : '$type · $category',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _addOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppText(
                        newsText.trim().isEmpty
                            ? 'Your short venue news will appear here.'
                            : newsText.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _addMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          const AppRatingStars(rating: 0, size: 15, spacing: 1),
                          AppText(
                            'No ratings yet',
                            style: TextStyle(
                              color: _addInk,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            localize: true,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: AppText(
                              'View info: Booking Card',
                              style: TextStyle(
                                color: _addMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                              localize: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNewsPost(Map<String, dynamic> post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Delete News Card?', localize: true),
        content: const AppText(
          'This will permanently delete this News Card. This action cannot be undone.',
          localize: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Cancel', localize: true),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Delete', localize: true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final id = _id(post['id']);
    if (id == null) {
      _showNewsCardMessage('Could not delete this News Card.');
      return;
    }
    try {
      final token = await _session.loadApiToken();
      if (token == null || token.isEmpty) {
        _showNewsCardMessage('Could not delete this News Card.');
        return;
      }
      await _api.venues.deleteMerchantNewsPost(token: token, id: id);
      await _loadNewsPosts(force: true);
    } on Exception catch (error) {
      _showNewsCardMessage('Could not delete News Card: $error');
    }
  }

  Future<void> _publishNewsPost(Map<String, dynamic> post) async {
    final id = _id(post['id']);
    try {
      final token = await _session.loadApiToken();
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Please sign in again.', 401);
      }
      if (id == null) {
        throw const FormatException('This News Card has an invalid ID.');
      }
      final rawImage =
          post['imageUrl'] ?? post['image_url'] ?? post['businessImageUrl'];
      await _api.venues.updateMerchantNewsPost(
        token: token,
        id: id,
        post: MerchantNewsPostDraft(
          businessId: _postBusinessId(post),
          title: '${post['title'] ?? ''}',
          body: '${post['body'] ?? ''}',
          imageUrl: rawImage is String ? rawImage : null,
          status: NewsPostStatus.published,
        ),
      );
      await widget.onBusinessesChanged();
      await _loadNewsPosts(force: true);
      final updatedPost = _newsPosts.where((item) => _id(item['id']) == id);
      if (updatedPost.isEmpty ||
          '${updatedPost.first['status'] ?? ''}'.toLowerCase() !=
              NewsPostStatus.published.name) {
        throw const AuthApiException(
          'The News Card was saved, but its published status could not be confirmed.',
          500,
        );
      }
      if (mounted) {
        _updateAddPageState(() {
          _selectedAddSection = 'Booking cards';
        });
      }
      if (mounted) _showNewsCardMessage('News Card published.');
    } on Exception catch (error) {
      _showNewsCardMessage('Could not publish News Card: $error');
    }
  }

  void _showNewsCardMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
  }
}
