# MuhOS: the WhiteSur GTK theme (macOS look for GTK 2, 3 and 4/libadwaita
# apps), not packaged by Fedora. Installs upstream's prebuilt Light and Dark
# releases from the tagged source, GTK parts only: the GNOME Shell, Cinnamon,
# Metacity, Unity, Xfwm and Plank themes are left out (MuhOS uses none of them).

%global tag 2026-09-10

Name:           whitesur-gtk-theme
Version:        %(echo %{tag} | tr -d -)
Release:        1.muhos1%{?dist}
Summary:        macOS-like GTK theme (WhiteSur)
License:        MIT
URL:            https://github.com/vinceliuice/WhiteSur-gtk-theme
Source0:        %{url}/archive/refs/tags/%{tag}.tar.gz#/WhiteSur-gtk-theme-%{tag}.tar.gz
BuildArch:      noarch

BuildRequires:  tar
BuildRequires:  xz

%description
WhiteSur is a macOS Big Sur and later style theme for GTK 2, GTK 3 and GTK 4
(including libadwaita) applications, in light and dark variants.

%prep
%autosetup -n WhiteSur-gtk-theme-%{tag}

%build
# Prebuilt by upstream (release/*.tar.xz); nothing to compile.

%install
install -d %{buildroot}%{_datadir}/themes
for v in Light Dark; do
    tar -xJf release/WhiteSur-$v.tar.xz -C %{buildroot}%{_datadir}/themes
    t=%{buildroot}%{_datadir}/themes/WhiteSur-$v
    rm -rf "$t"/{cinnamon,gnome-shell,metacity-1,plank,unity,xfwm4}
done

%files
%license COPYING
%doc README.md
%{_datadir}/themes/WhiteSur-Light/
%{_datadir}/themes/WhiteSur-Dark/

%changelog
* Tue Nov 24 2026 MuhOS contributors - 20260910-1.muhos1
- First MuhOS package: WhiteSur 2026-09-10, Light and Dark GTK themes
