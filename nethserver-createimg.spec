Name:      nethserver-createimg
Version:   0.0.1
Release:   1%{?dist}
Summary:   Create NethServer-arm Disk-Images
BuildArch: noarch

License:   GPLv3
URL:       http://www.nethserver.org
Source0:   %{name}-%{version}.tar.gz

Requires:  appliance-tools


%description
Provides build automation for NethServer-arm Disk-Images

%prep
%setup -q

%build

%install
rm -rf %{buildroot}
mkdir -p  %{buildroot}/%{_defaultdocdir}/appliance-tools
install -vp root/usr/share/doc/appliance-tools/* %{buildroot}/%{_defaultdocdir}/appliance-tools

%files
%defattr(-,root,root,-)
%doc COPYING
%{_defaultdocdir}/appliance-tools/*


%changelog
* Tue Jul 10 2018 Mark Verlinde <mark.verlinde@gmail.com> - 0.0.1-1
- Initial test build

