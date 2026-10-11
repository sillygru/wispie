#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>

#include "resource.h"

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  icon_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "wispie/app_icon",
      &flutter::StandardMethodCodec::GetInstance());
  icon_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "setAppIcon") {
          result->NotImplemented();
          return;
        }
        // Resource ids are IDI_APP_ICON + the variant's index.
        int index = 0;
        if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
          auto it = args->find(flutter::EncodableValue("index"));
          if (it != args->end()) {
            if (const auto* i = std::get_if<int32_t>(&it->second)) index = *i;
          }
        }
        ApplyIcon(IDI_APP_ICON + index);
        result->Success();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::ApplyIcon(int resource_id) {
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  HINSTANCE inst = GetModuleHandle(nullptr);
  auto load = [&](int cx, int cy) {
    return reinterpret_cast<HICON>(LoadImage(
        inst, MAKEINTRESOURCE(resource_id), IMAGE_ICON, cx, cy, LR_DEFAULTCOLOR));
  };
  HICON big = load(GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON));
  HICON small_icon = load(GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON));
  if (big) SendMessage(hwnd, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(big));
  if (small_icon) SendMessage(hwnd, WM_SETICON, ICON_SMALL, reinterpret_cast<LPARAM>(small_icon));
}

void FlutterWindow::OnDestroy() {
  icon_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
