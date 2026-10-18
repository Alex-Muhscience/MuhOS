# MuhOS: Material Symbols Rounded, the variable icon font MuhOS uses for the
# shell's own symbols (filled style). Not packaged in Fedora 44.

%global commit 49d4db35df873165d6bd6ba09b063c7dafbac2f4
%global shortcommit %(c=%{commit}; echo ${c:0:7})
%global commitdate 20261009
%global fontdir %{_datadir}/fonts/material-symbols-rounded

Name:           material-symbols-rounded-fonts
Version:        0^%{commitdate}git%{shortcommit}
Release:        1.muhos1%{?dist}
Summary:        Material Symbols Rounded variable icon font
License:        Apache-2.0
URL:            https://github.com/google/material-design-icons
Source0:        https://raw.githubusercontent.com/google/material-design-icons/%{commit}/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf#/MaterialSymbolsRounded.ttf
Source1:        https://raw.githubusercontent.com/google/material-design-icons/%{commit}/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.codepoints#/MaterialSymbolsRounded.codepoints
Source2:        https://raw.githubusercontent.com/google/material-design-icons/%{commit}/LICENSE#/LICENSE

BuildArch:      noarch
BuildRequires:  fontconfig
Requires:       fontconfig

%description
Material Symbols Rounded is Google's variable icon font: over 3,000 symbols
with adjustable fill, weight, grade and optical size. Icons are selected by
ligature name, for example "settings" or "wifi".

%prep
%setup -c -T
cp -p %{SOURCE0} %{SOURCE1} %{SOURCE2} .

%build

%install
install -Dm 0644 MaterialSymbolsRounded.ttf %{buildroot}%{fontdir}/MaterialSymbolsRounded.ttf
install -Dm 0644 MaterialSymbolsRounded.codepoints %{buildroot}%{fontdir}/MaterialSymbolsRounded.codepoints

%check
# fontconfig must see the family name the shell asks for.
fc-scan --format "%%{family}\n" MaterialSymbolsRounded.ttf | grep -qx "Material Symbols Rounded"

%files
%license LICENSE
%dir %{fontdir}
%{fontdir}/MaterialSymbolsRounded.ttf
%{fontdir}/MaterialSymbolsRounded.codepoints

%changelog
* Mon Oct 19 2026 MuhOS contributors - 0^20261009git49d4db3-1.muhos1
- Initial package for MuhOS
