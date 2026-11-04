import 'package:flutter/widgets.dart';

class CustomerNavigationScope extends InheritedWidget {
  const CustomerNavigationScope({
    super.key,
    required this.onDestinationSelected,
    required this.onUnreadBookingCountChanged,
    required super.child,
  });

  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<int> onUnreadBookingCountChanged;

  static CustomerNavigationScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CustomerNavigationScope>();

  @override
  bool updateShouldNotify(CustomerNavigationScope oldWidget) =>
      onDestinationSelected != oldWidget.onDestinationSelected ||
      onUnreadBookingCountChanged != oldWidget.onUnreadBookingCountChanged;
}
