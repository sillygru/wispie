use serde_json::{json, Value};
use std::path::{Component, Path, PathBuf};

pub fn destination(original_url: &str, source_path: &str) -> String {
    let name = basename(source_path);
    let parent = Path::new(original_url)
        .parent()
        .unwrap_or_else(|| Path::new("."));
    if name.is_empty() {
        parent.to_string_lossy().into_owned()
    } else {
        parent.join(name).to_string_lossy().into_owned()
    }
}

pub fn filename(source_path: &str) -> String {
    basename(source_path.trim())
}

fn basename(source_path: &str) -> String {
    let source = Path::new(source_path);
    match source.file_name() {
        Some(name) => name.to_string_lossy().into_owned(),
        None if source.has_root() => source.as_os_str().to_string_lossy().into_owned(),
        None => String::new(),
    }
}

pub fn check(request: &Value) -> Value {
    let source = string(request, "sourcePath").trim().to_string();
    if source.is_empty() {
        return rejected("noFileSelected", None);
    }
    if !request
        .get("isSupportedMediaFile")
        .and_then(Value::as_bool)
        .unwrap_or(false)
    {
        return rejected("unsupportedFormat", None);
    }

    let new_filename = filename(&source);
    if new_filename.is_empty()
        || new_filename.eq_ignore_ascii_case(string(request, "originalFilename"))
    {
        return rejected("sameFilename", None);
    }

    let tracked = request
        .get("trackedFolders")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    if tracked.iter().filter_map(Value::as_str).any(|folder| {
        is_within(
            &normalize(Path::new(&source)),
            &normalize(Path::new(folder.trim())),
        )
    }) {
        return rejected("insideLibrary", None);
    }

    let library_names = request
        .get("libraryFilenames")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    if library_names
        .iter()
        .filter_map(Value::as_str)
        .any(|name| name.eq_ignore_ascii_case(&new_filename))
    {
        return rejected("libraryHasName", Some(new_filename));
    }

    let destination_exists = request
        .get("destinationExists")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if destination_exists
        && !request
            .get("overwriteDestination")
            .and_then(Value::as_bool)
            .unwrap_or(false)
    {
        return rejected("destinationExists", Some(new_filename));
    }

    json!({
        "accepted": true,
        "sourcePath": source,
        "newFilename": new_filename,
        "destinationPath": destination(string(request, "originalUrl"), &source),
        "overwritesDestination": destination_exists,
    })
}

fn rejected(reason: &str, filename: Option<String>) -> Value {
    let mut value = json!({"accepted": false, "reason": reason});
    if let Some(filename) = filename {
        value["filename"] = Value::String(filename);
    }
    value
}

fn string<'a>(value: &'a Value, key: &str) -> &'a str {
    value.get(key).and_then(Value::as_str).unwrap_or("")
}

fn normalize(path: &Path) -> PathBuf {
    let mut result = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => {
                if !result.pop() && !path.is_absolute() {
                    result.push(component.as_os_str());
                }
            }
            _ => result.push(component.as_os_str()),
        }
    }
    result
}

fn is_within(path: &Path, root: &Path) -> bool {
    !root.as_os_str().is_empty() && path.starts_with(root)
}
