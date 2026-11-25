use serde::Serialize;

#[derive(Serialize)]
pub struct BackupPreferenceCategory {
    pub name: &'static str,
    pub keys: &'static [&'static str],
}

pub const THEME: &[&str] = &["theme_mode", "use_cover_color", "apply_cover_color_to_all"];
pub const SCANNER: &[&str] = &[
    "music_folders_list",
    "lyrics_folders_list",
    "excluded_folders",
    "last_library_folder",
    "minimum_file_size_bytes",
    "minimum_track_duration_ms",
    "include_videos",
    "prevent_duplicate_tracks",
    "prevent_merged_duplicates",
    "extract_feat_artists",
];
pub const PLAYBACK: &[&str] = &[
    "play_fade_duration",
    "pause_fade_duration",
    "gap_song_id",
    "gap_resume_timestamp",
    "gap_is_active",
    "fade_in_duration",
    "fade_out_duration",
    "delay_duration",
    "auto_pause_on_volume_zero",
    "auto_resume_on_volume_restore",
    "keep_screen_awake_on_lyrics",
    "desktop_sidebar_enabled",
    "lyrics_simulated_rich_sync_enabled",
    "lyrics_target_language",
    "lyrics_auto_translate",
    "lyrics_translation_mode",
];
pub const UI: &[&str] = &[
    "sort_order",
    "visualizer_enabled",
    "visualizer_mode",
    "auto_hide_bottom_bar_on_scroll",
    "show_song_duration",
    "animated_sound_wave_enabled",
    "show_waveform",
    "progress_bar_type",
    "waveform_haptics_enabled",
    "curved_scrollbar_enabled",
    "scrollbar_corner_radius",
    "bottom_nav_corner_style",
    "bottom_nav_corner_radius",
    "quick_action_config",
    "cover_sizing_mode",
    "beat_reactive_cover_enabled",
    "beat_reactive_particles_enabled",
    "cover_motion_intensity",
    "particle_motion_intensity",
    "cover_motion_custom_intensity",
    "particle_motion_custom_intensity",
    "player_motion_latency_ms",
    "player_swipe_changes_pane",
    "spin_artwork_while_playing",
    "show_quick_picks",
    "show_recent_queues",
    "show_for_you",
    "youtube_enabled",
    "youtube_hidden_playlists",
    "sound_reactive_particles_enabled",
    "pull_to_refresh_enabled",
    "app_icon_style",
];
pub const BACKUP: &[&str] = &[
    "auto_backup_frequency_hours",
    "auto_backup_delete_after_days",
    "auto_backup_content_types",
];
pub const IDENTITY: &[&str] = &[
    "username",
    "local_username",
    "is_local_mode",
    "is_setup_complete_v2",
    "telemetry_id",
];

pub const CATEGORIES: &[BackupPreferenceCategory] = &[
    BackupPreferenceCategory {
        name: "theme",
        keys: THEME,
    },
    BackupPreferenceCategory {
        name: "scanner",
        keys: SCANNER,
    },
    BackupPreferenceCategory {
        name: "playback",
        keys: PLAYBACK,
    },
    BackupPreferenceCategory {
        name: "ui",
        keys: UI,
    },
    BackupPreferenceCategory {
        name: "backup",
        keys: BACKUP,
    },
];
