import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_design_system.dart';
import '../../../app_text.dart';
import '../application/auth_service.dart';

class CustomerOnboardingPage extends StatefulWidget {
  const CustomerOnboardingPage({
    super.key,
    required this.service,
    required this.token,
    this.firstName,
  });

  final AuthService service;
  final String token;
  final String? firstName;

  @override
  State<CustomerOnboardingPage> createState() => _CustomerOnboardingPageState();
}

class _CustomerOnboardingPageState extends State<CustomerOnboardingPage> {
  static const _sports = [
    'Basketball',
    'Volleyball',
    'Badminton',
    'Tennis',
    'Football',
    'Swimming',
    'Running',
  ];

  int _step = 0;
  String? _gender;
  String? _playerType;
  final Set<String> _hobbies = {};
  final _hobbyInputController = TextEditingController();
  bool _saving = false;
  bool _saveFailed = false;
  Object? _error;
  bool _complete = false;
  Timer? _welcomeTimer;

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    _hobbyInputController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_step == 0 && _gender == null) {
      setState(() {
        _saveFailed = false;
        _error = 'Choose an option to continue.';
      });
      return;
    }
    setState(() {
      _saveFailed = false;
      _error = null;
      _step++;
    });
  }

  void _skip() {
    final isFinalStep = _step == 2;
    setState(() {
      if (_step == 1) _playerType = null;
      if (_step == 2) {
        _hobbies.clear();
        _hobbyInputController.clear();
      }
      if (!isFinalStep) _step++;
      _saveFailed = false;
      _error = null;
    });
    if (isFinalStep) _save();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
      _error = null;
    });
    try {
      await widget.service.completeCustomerOnboarding(
        token: widget.token,
        gender: _gender!,
        playerType: _playerType,
        hobby: _hobbies.join(', '),
      );
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted) {
        setState(() => _complete = true);
        _welcomeTimer = Timer(const Duration(milliseconds: 2200), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _saveFailed = true;
          _error = error;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleHobby(String hobby) {
    setState(() {
      if (_hobbies.contains(hobby)) {
        _hobbies.remove(hobby);
      } else {
        final nextLength =
            _hobbies.join(', ').length +
            (_hobbies.isEmpty ? 0 : 2) +
            hobby.length;
        if (nextLength > 255) {
          _saveFailed = false;
          _error = 'Keep your activity list under 255 characters.';
          return;
        }
        _hobbies.add(hobby);
      }
      _saveFailed = false;
      _error = null;
    });
  }

  void _addCustomHobby() {
    final hobby = _hobbyInputController.text.trim();
    if (hobby.isEmpty) return;
    final duplicate = _hobbies.any(
      (existing) => existing.toLowerCase() == hobby.toLowerCase(),
    );
    final nextLength =
        _hobbies.join(', ').length + (_hobbies.isEmpty ? 0 : 2) + hobby.length;
    if (!duplicate && nextLength > 255) {
      setState(() {
        _saveFailed = false;
        _error = 'Keep your activity list under 255 characters.';
      });
      return;
    }
    if (!duplicate) _toggleHobby(hobby);
    _hobbyInputController.clear();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('onboarding-back'),
                    onPressed: _complete || _step == 0 || _saving
                        ? null
                        : () => setState(() {
                            _step--;
                            _error = null;
                          }),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Expanded(
                    child: AppText(
                      'Set up your profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                key: const ValueKey('customer-onboarding-progress'),
                value: _complete ? 1 : (_step + 1) / 3,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: AppColors.softSurface,
                color: AppColors.accent,
              ),
              const SizedBox(height: 10),
              AppText(
                _complete
                    ? 'All set'
                    : _saving
                    ? 'Saving your profile'
                    : 'Step ${_step + 1} of 3',
                key: const ValueKey('customer-onboarding-step-label'),
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _saving
                      ? _buildSaving()
                      : _complete
                      ? _buildWelcome()
                      : _buildStep(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppText(
                    _saveFailed
                        ? 'Could not save your answers: $_error'
                        : '$_error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (!_saving && !_complete) _buildActions(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildStep() => SingleChildScrollView(
    key: ValueKey('customer-onboarding-step-$_step'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          switch (_step) {
            0 => Icons.person_outline_rounded,
            1 => Icons.sports_handball_rounded,
            _ => Icons.favorite_border_rounded,
          },
          size: 34,
          color: AppColors.accent,
        ),
        const SizedBox(height: 16),
        AppText(switch (_step) {
          0 => 'How should we identify you?',
          1 => 'What best describes you?',
          _ => 'What sports or activities do you enjoy?',
        }, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        AppText(switch (_step) {
          0 => 'Choose an option. You can prefer not to say.',
          1 => 'Help us tailor recommendations to you.',
          _ => 'Choose all that apply so we can personalize your feed.',
        }, style: TextStyle(color: AppColors.muted, height: 1.45)),
        const SizedBox(height: 24),
        if (_step == 0)
          _buildChoices(
            [
              ('male', 'Male', Icons.male_rounded),
              ('female', 'Female', Icons.female_rounded),
              (
                'prefer_not_to_say',
                'Prefer not to say',
                Icons.more_horiz_rounded,
              ),
            ],
            _gender,
            (value) => setState(() {
              _gender = value;
              _error = null;
            }),
          ),
        if (_step == 1)
          _buildChoices(
            [
              ('New player', 'New player', Icons.waving_hand_rounded),
              ('Athlete', 'Athlete', Icons.directions_run_rounded),
              (
                'Recreational player',
                'Recreational player',
                Icons.sports_tennis_rounded,
              ),
              (
                'Returning player',
                'Returning player',
                Icons.restart_alt_rounded,
              ),
              ('Other', 'Other', Icons.more_horiz_rounded),
            ],
            _playerType,
            (value) => setState(() => _playerType = value),
          ),
        if (_step == 2) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hobby in _hobbies)
                InputChip(
                  key: ValueKey('onboarding-selected-hobby-$hobby'),
                  label: AppText(hobby),
                  onDeleted: () => _toggleHobby(hobby),
                  deleteIconColor: AppColors.accent,
                  backgroundColor: AppColors.softOrange,
                ),
            ],
          ),
          if (_hobbies.isNotEmpty) const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('onboarding-hobby-input'),
                  controller: _hobbyInputController,
                  maxLength: 80,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addCustomHobby(),
                  decoration: const InputDecoration(
                    labelText: 'Add any sport or hobby',
                    hintText: 'e.g. hiking, dance, or chess',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const ValueKey('onboarding-add-hobby'),
                onPressed: _addCustomHobby,
                tooltip: 'Add activity',
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppText(
            'Pick suggestions or enter your own. Choose as many as you like.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final sport in _sports)
                FilterChip(
                  key: ValueKey('onboarding-hobby-$sport'),
                  label: AppText(sport),
                  selected: _hobbies.contains(sport),
                  onSelected: (_) => _toggleHobby(sport),
                  showCheckmark: true,
                ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _buildChoices(
    List<(String, String, IconData)> choices,
    String? selected,
    ValueChanged<String> onSelected,
  ) => Column(
    children: [
      for (final (value, label, icon) in choices)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            key: ValueKey('onboarding-choice-$value'),
            onTap: () => onSelected(value),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: selected == value
                    ? AppColors.softOrange
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected == value
                      ? AppColors.accent
                      : AppColors.border,
                  width: selected == value ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppText(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (selected == value)
                    Icon(Icons.check_circle_rounded, color: AppColors.accent),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _buildWelcome() => Center(
    key: const ValueKey('customer-onboarding-welcome'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: .65, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          builder: (context, value, child) =>
              Transform.scale(scale: value, child: child),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.softOrange,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sports_tennis_rounded,
              size: 42,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppText(
          'Welcome${widget.firstName?.trim().isNotEmpty == true ? ', ${widget.firstName}' : ''}!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        AppText(
          'Your SpotGo experience is ready. Let’s find your next game.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        if (_hobbies.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hobby in _hobbies)
                Chip(
                  avatar: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  label: AppText(hobby),
                  backgroundColor: AppColors.softOrange,
                ),
            ],
          ),
        ],
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            AppText(
              'Taking you to your Home feed…',
              key: const ValueKey('customer-onboarding-home-transition'),
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildSaving() => Center(
    key: const ValueKey('customer-onboarding-saving'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 24),
        const AppText(
          'Getting your profile ready…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        AppText(
          'Saving your answers and personalizing your experience.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.45),
        ),
      ],
    ),
  );

  Widget _buildActions() => Row(
    children: [
      if (_step > 0 && _step < 3)
        TextButton(
          key: ValueKey('customer-onboarding-skip-$_step'),
          onPressed: _saving ? null : _skip,
          child: const AppText('Skip'),
        ),
      const Spacer(),
      Expanded(
        flex: 2,
        child: FilledButton(
          key: ValueKey('customer-onboarding-next-$_step'),
          onPressed: _saving
              ? null
              : _step < 2
              ? _continue
              : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: AppText(_step < 2 ? 'Continue' : 'Finish', localize: true),
        ),
      ),
    ],
  );
}
