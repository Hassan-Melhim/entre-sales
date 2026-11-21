import 'package:flutter/material.dart';

/// The people who sign in at the till: a name and icon on the login screen,
/// and the email of their Supabase login (Authentication → Users).
class StaffAccount {
  final String name;
  final String email;
  final IconData icon;
  const StaffAccount(this.name, this.email, this.icon);
}

const List<StaffAccount> staffAccounts = [
  StaffAccount('Sofia', 'sophiepoln@gmail.com', Icons.pets),
  StaffAccount('Norhan', 'norhanmadkour@gmail.com', Icons.headphones),
  StaffAccount('Jerome', 'jeromeg1996@gmail.com', Icons.carpenter),
];

/// The staff member signed in with [email], if it is one of [staffAccounts].
StaffAccount? staffFor(String? email) {
  final e = email?.trim().toLowerCase();
  for (final s in staffAccounts) {
    if (s.email.toLowerCase() == e) return s;
  }
  return null;
}

/// Logins that are not shown on the sign-in screen, by email → name.
const Map<String, String> otherAccountNames = {
  'hassanmelhim2@gmail.com': 'Hasan',
};

/// A person's name for [email] (staff or other known logins), else the email.
String accountName(String? email) {
  final e = email?.trim().toLowerCase() ?? '';
  return staffFor(e)?.name ?? otherAccountNames[e] ?? (e.isEmpty ? 'someone' : e);
}
