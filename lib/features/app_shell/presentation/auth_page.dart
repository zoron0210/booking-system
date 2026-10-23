part of 'app_root.dart';

enum _AuthMode { login, register }

enum _AccountRole { customer, merchant }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  _AuthMode _mode = _AuthMode.login;
  _AccountRole _role = _AccountRole.customer;
  bool _obscurePassword = true;

  void _showComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(
          '$provider sign in will be connected soon.',
          localize: true,
        ),
        backgroundColor: _navy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: _navy,
              ),
              const SizedBox(height: 6),
              Center(
                child: Image.asset(
                  'assets/tinker_logo.png',
                  width: 76,
                  height: 58,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: AppText(
                  isLogin ? 'Welcome back' : 'Create your account',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: AppText(
                  isLogin
                      ? 'Sign in to continue your game.'
                      : 'Join TinkerPro and get in the game.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 6),
              _AuthModeToggle(
                mode: _mode,
                onChanged: (mode) => setState(() => _mode = mode),
              ),
              const SizedBox(height: 6),
              if (!isLogin) ...[
                AppText(
                  'I am joining as',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  localize: true,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.person_rounded,
                        title: 'Player',
                        subtitle: 'Book and play',
                        selected: _role == _AccountRole.customer,
                        onTap: () =>
                            setState(() => _role = _AccountRole.customer),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.storefront_rounded,
                        title: 'Merchant',
                        subtitle: 'Manage facilities',
                        selected: _role == _AccountRole.merchant,
                        onTap: () =>
                            setState(() => _role = _AccountRole.merchant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              _AuthField(
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 6),
              _AuthField(
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              if (!isLogin) ...[
                const SizedBox(height: 6),
                const _AuthField(
                  label: 'Confirm password',
                  hint: 'Repeat your password',
                  icon: Icons.verified_user_outlined,
                  obscureText: true,
                ),
              ],
              if (isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showComingSoon('Password recovery'),
                    child: const AppText('Forgot password?', localize: true),
                  ),
                )
              else
                const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _showComingSoon(
                    isLogin
                        ? 'Email login'
                        : '${_role == _AccountRole.merchant ? 'Merchant' : 'Customer'} registration',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(53),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  child: AppText(isLogin ? 'Sign in' : 'Create account'),
                ),
              ),
              const SizedBox(height: 6),
              const _OrDivider(),
              const SizedBox(height: 6),
              _SocialButton(
                label: 'Continue with Google',
                mark: 'G',
                onTap: () => _showComingSoon('Google'),
              ),
              const SizedBox(height: 6),
              Center(
                child: AppText.rich(
                  TextSpan(
                    text: isLogin
                        ? 'New to TinkerPro? '
                        : 'Already have an account? ',
                    style: TextStyle(color: _muted, fontSize: 13),
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _mode = isLogin
                                ? _AuthMode.register
                                : _AuthMode.login,
                          ),
                          child: AppText(
                            isLogin ? 'Register' : 'Sign in',
                            style: TextStyle(
                              color: _orange,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  localize: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF4),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          _ToggleOption(
            label: 'Sign in',
            selected: mode == _AuthMode.login,
            onTap: () => onChanged(_AuthMode.login),
          ),
          _ToggleOption(
            label: 'Register',
            selected: mode == _AuthMode.register,
            onTap: () => onChanged(_AuthMode.register),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: AppText(
            label,
            style: TextStyle(
              color: selected ? _navy : _muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: selected ? _navy : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? _orange : const Color(0xFFE4E8EF),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? _orange : _muted, size: 24),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                AppText(
                  subtitle,
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withValues(alpha: .65)
                        : _muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        label,
        localize: true,
        style: TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: appLanguageText(hint, hint),
          prefixIcon: Icon(icon, color: _muted, size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: AppColors.surface,
          hintStyle: const TextStyle(color: Color(0xFF9CA6B5), fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _orange, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: Color(0xFFDDE2EA))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: AppText(
          'OR CONTINUE WITH',
          style: TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
          localize: true,
        ),
      ),
      const Expanded(child: Divider(color: Color(0xFFDDE2EA))),
    ],
  );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.mark,
    required this.onTap,
  });

  final String label;
  final String mark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(51),
      backgroundColor: AppColors.surface,
      foregroundColor: _ink,
      side: const BorderSide(color: Color(0xFFE1E6EE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppText(
          mark,
          style: TextStyle(
            color: _navy,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 6),
        AppText(
          label,
          style: TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
