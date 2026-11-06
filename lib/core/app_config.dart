/// Which Supabase project the website talks to.
///
/// Both values are public by design: the publishable key only identifies the
/// project, and the database's own rules decide what a signed-in owner may
/// do. (Never put the *secret* key here.)
///
/// To use another project without changing the code, build with
///   --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mddsniqoqhutzthbleve.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_IzHJKaJuukexKlBXW8omVg_5XBFypuE',
  );
}

/// The logos printed on PDFs, read from Supabase Storage (bucket and file
/// names exactly as they appear there). A missing file just leaves that
/// logo out.
abstract final class LogoFiles {
  static const bucket = 'Logos & Icons';

  /// Top corner of every invoice and receipt.
  static const corner = 'ES_GoogleProfileThumbnail.png';

  /// Across the bottom of each page.
  static const footer = 'ES_Logo_3d_horizontalThumbnail.png';

  /// The three kisses, next to the title.
  static const kisses = 'ES_stamp_kissingThumbnail.png';
}
