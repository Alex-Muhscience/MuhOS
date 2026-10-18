# MuhOS: Quickshell 0.3.2 for Fedora 44, which ships 0.2.1. Based on the
# Fedora quickshell spec (src.fedoraproject.org/rpms/quickshell); changes:
# version 0.3.2, crash handler off (cpptrace is not packaged in Fedora),
# build dependencies added in 0.3.x (Vulkan headers, polkit-gobject, xcb).

# Not available in RHEL
%bcond x11 %[%{undefined rhel}]

Name:               quickshell
Version:            0.3.2
Release:            1.muhos1%{?dist}
Summary:            Flexible QtQuick based desktop shell toolkit
# Code is LGPL, Hyprland protocols are BSD-3-Clause, wlr protocols are HPND-sell-variant
License:            LGPL-3.0-or-later AND BSD-3-Clause AND HPND-sell-variant
URL:                https://quickshell.org/
Source:             https://git.outfoxxed.me/%{name}/%{name}/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz

BuildRequires:      cmake
BuildRequires:      cmake(Qt6Core)
BuildRequires:      cmake(Qt6Qml)
BuildRequires:      cmake(Qt6CorePrivate)
BuildRequires:      cmake(Qt6QuickPrivate)
BuildRequires:      cmake(Qt6ShaderTools)
BuildRequires:      cmake(Qt6WaylandClient)
BuildRequires:      cmake(VulkanHeaders)
BuildRequires:      desktop-file-utils
BuildRequires:      gcc-c++
BuildRequires:      ninja-build
BuildRequires:      pkgconfig(CLI11)
BuildRequires:      pkgconfig(egl)
BuildRequires:      pkgconfig(gbm)
BuildRequires:      pkgconfig(glib-2.0)
BuildRequires:      pkgconfig(gobject-2.0)
BuildRequires:      pkgconfig(jemalloc)
BuildRequires:      pkgconfig(libdrm)
BuildRequires:      pkgconfig(libpipewire-0.3)
BuildRequires:      pkgconfig(pam)
BuildRequires:      pkgconfig(polkit-agent-1)
BuildRequires:      pkgconfig(polkit-gobject-1)
BuildRequires:      pkgconfig(wayland-client)
BuildRequires:      pkgconfig(wayland-protocols)
BuildRequires:      spirv-tools
%if %{with x11}
BuildRequires:      pkgconfig(xcb)
%endif

# Add undetectable runtime dependencies
Requires:           qt6-qtsvg%{?_isa}

Provides:           desktop-notification-daemon = %{version}-%{release}
Provides:           PolicyKit-authentication-agent = %{version}-%{release}

%description
Quickshell is a toolkit for building status bars, widgets,
lockscreens, and other desktop components using QtQuick.

It can be used alongside a Wayland compositor to build
a complete desktop environment.

%prep
%autosetup -n %{name}

%conf
%cmake  -GNinja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_SKIP_INSTALL_RPATH=ON \
        -DDISTRIBUTOR="MuhOS (Fedora %{fedora})" \
        -DDISTRIBUTOR_DEBUGINFO_AVAILABLE=YES \
        -DINSTALL_QML_PREFIX=%{_lib}/qt6/qml \
        -DCRASH_HANDLER=OFF \
        -DX11=%{?with_x11:ON}%{!?with_x11:OFF} \
        %{nil}

%build
%cmake_build

%install
%cmake_install

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/*.desktop

%files
%license LICENSE*
%doc BUILD.md CONTRIBUTING.md README.md changelog/
%{_bindir}/qs
%{_bindir}/quickshell
%{_datadir}/applications/org.quickshell.desktop
%{_datadir}/icons/hicolor/scalable/apps/org.quickshell.svg
%{_qt6_qmldir}/Quickshell/

%changelog
* Sun Oct 18 2026 MuhOS contributors - 0.3.2-1.muhos1
- Update to 0.3.2 for MuhOS; disable the cpptrace crash handler
