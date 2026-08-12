class Qemu < Formula
  desc "Generic machine emulator and virtualizer"
  homepage "https://www.qemu.org/"
  url "https://download.qemu.org/qemu-11.1.0.tar.xz"
  sha256 "6ee1d1a61f68212476b27108c26da5f449dc09b626d42f8279ba0dc2e08fa858"
  license "GPL-2.0-only"
  compatibility_version 1
  head "https://gitlab.com/qemu-project/qemu.git", branch: "master"

  livecheck do
    url "https://www.qemu.org/download/"
    regex(/href=.*?qemu[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    sha256 arm64_tahoe:   "cad70866b9b9c6e9e88c4b250637ea0c9fb7227d99bf36f58e5e32eeb5536f55"
    sha256 arm64_sequoia: "22fbe3c94472e124eaa4829b776bc3e7228c1a94b8ba5783229d422ca3e64763"
    sha256 arm64_sonoma:  "16bc71899cd919e69258abe366a9ed0a7d8211efd809330ecc03a50e53b9efba"
    sha256 sonoma:        "ea65f5d43bad7b097b28a5e07047212de59cd1205f9a85eb2cbf019c4a25fe5e"
    sha256 arm64_linux:   "b8599b302b0f4d38e280d6bf2b3c8dd96d3c195f8f3f798c68233c2afb686b31"
    sha256 x86_64_linux:  "d4066d891b708a60cdf91a853dc67b9bc7162efd1db74a6099f20db71bfb5621"
  end

  depends_on "bison" => :build # >= 3.0
  depends_on "libtool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "python-setuptools" => :build
  depends_on "python@3.14" => :build # keep aligned with meson
  depends_on "spice-protocol" => :build

  depends_on "capstone"
  depends_on "dtc"
  depends_on "glib"
  depends_on "gnutls"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "libslirp"
  depends_on "libssh"
  depends_on "libusb"
  depends_on "lzo"
  depends_on "ncurses"
  depends_on "pixman"
  depends_on "snappy"
  depends_on "vde"
  depends_on "zstd"

  uses_from_macos "flex" => :build
  uses_from_macos "bzip2"

  on_linux do
    depends_on "attr"
    depends_on "cairo"
    depends_on "elfutils"
    depends_on "gdk-pixbuf"
    depends_on "gtk+3"
    depends_on "keyutils"
    depends_on "libcap-ng"
    depends_on "libepoxy"
    depends_on "libx11"
    depends_on "libxkbcommon"
    depends_on "mesa"
    depends_on "systemd"
    depends_on "zlib-ng-compat"
  end

  # Stub EL2 sysregs absent from the macOS 14 SDK
  patch :DATA

  def install
    ENV["LIBTOOL"] = "glibtool"

    # Remove wheels unless explicitly permitted. Currently this:
    # * removes `meson` so that brew `meson` is always used
    # * keeps `pycotap` and `qemu_qmp` which are pure-python "none-any" wheels (allowed in homebrew/core)
    rm(Dir["python/wheels/*"] - Dir["python/wheels/{pycotap,qemu_qmp}-*-none-any.whl"])

    args = %W[
      --prefix=#{prefix}
      --cc=#{ENV.cc}
      --host-cc=#{ENV.cc}
      --disable-bsd-user
      --disable-download
      --disable-guest-agent
      --enable-slirp
      --enable-capstone
      --enable-curses
      --enable-fdt=system
      --enable-libssh
      --enable-vde
      --enable-virtfs
      --enable-zstd
      --extra-cflags=-DNCURSES_WIDECHAR=1
      --disable-sdl
    ]

    # Sharing Samba directories in QEMU requires the samba.org smbd which is
    # incompatible with the macOS-provided version. This will lead to
    # silent runtime failures, so we set it to a Homebrew path in order to
    # obtain sensible runtime errors. This will also be compatible with
    # Samba installations from external taps.
    args << "--smbd=#{HOMEBREW_PREFIX}/sbin/samba-dot-org-smbd"

    args += if OS.mac?
      ["--disable-gtk", "--enable-cocoa"]
    else
      ["--enable-gtk"]
    end

    system "./configure", *args
    system "make", "V=1", "install"
  end

  test do
    archs = %w[
      aarch64 alpha arm avr hppa i386 loongarch64 m68k microblaze mips
      mips64 mips64el mipsel or1k ppc ppc64 riscv32 riscv64 rx
      s390x sh4 sh4eb sparc sparc64 tricore x86_64 xtensa xtensaeb
    ]
    archs.each do |guest_arch|
      assert_match version.to_s, shell_output("#{bin}/qemu-system-#{guest_arch} --version")
    end

    system bin/"qemu-img", "create", "-f", "qcow2", "test.qcow2", "1440k"
    assert_match "file format: qcow2", shell_output("#{bin}/qemu-img info test.qcow2")

    system bin/"qemu-img", "convert", "-O", "raw", "test.qcow2", "test.img"
    assert_match "file format: raw", shell_output("#{bin}/qemu-img info test.img")

    # On macOS, verify that we haven't clobbered the signature on the qemu-system-x86_64 binary
    if OS.mac?
      output = shell_output("codesign --verify --verbose #{bin}/qemu-system-x86_64 2>&1")
      assert_match "valid on disk", output
      assert_match "satisfies its Designated Requirement", output
    end
  end
end

__END__
--- a/target/arm/hvf_arm.h
+++ b/target/arm/hvf_arm.h
@@ -68,4 +68,10 @@
   #include "hvf/hvf_sme_stubs.h"
 #endif /* ifdef __MAC_OS_X_VERSION_MAX_ALLOWED */
 
+/* The EL2 sysregs and nested virt config calls need macOS SDK >= 15.0. */
+#if defined(__aarch64__) && defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && \
+    (__MAC_OS_X_VERSION_MAX_ALLOWED < 150000)
+  #include "hvf/hvf_el2_stubs.h"
 #endif
+
+#endif
--- /dev/null
+++ b/target/arm/hvf/hvf_el2_stubs.h
@@ -0,0 +1,39 @@
+/* SPDX-License-Identifier: GPL-2.0-or-later */
+
+/* Ids as asserted in sysreg.c.inc; MDCR_EL2 is omitted because hvf.c defines it. */
+
+enum {
+    HV_SYS_REG_CNTHCTL_EL2 = 0xe708,
+    HV_SYS_REG_CNTHP_TVAL_EL2 = 0xe710,
+    HV_SYS_REG_CNTVOFF_EL2 = 0xe703,
+    HV_SYS_REG_CPTR_EL2 = 0xe08a,
+    HV_SYS_REG_ELR_EL2 = 0xe201,
+    HV_SYS_REG_ESR_EL2 = 0xe290,
+    HV_SYS_REG_FAR_EL2 = 0xe300,
+    HV_SYS_REG_HCR_EL2 = 0xe088,
+    HV_SYS_REG_HPFAR_EL2 = 0xe304,
+    HV_SYS_REG_MAIR_EL2 = 0xe510,
+    HV_SYS_REG_SCTLR_EL2 = 0xe080,
+    HV_SYS_REG_SPSR_EL2 = 0xe200,
+    HV_SYS_REG_SP_EL2 = 0xf208,
+    HV_SYS_REG_TCR_EL2 = 0xe102,
+    HV_SYS_REG_TPIDR_EL2 = 0xe682,
+    HV_SYS_REG_TTBR0_EL2 = 0xe100,
+    HV_SYS_REG_TTBR1_EL2 = 0xe101,
+    HV_SYS_REG_VBAR_EL2 = 0xe600,
+    HV_SYS_REG_VMPIDR_EL2 = 0xe005,
+    HV_SYS_REG_VPIDR_EL2 = 0xe000,
+    HV_SYS_REG_VTCR_EL2 = 0xe10a,
+    HV_SYS_REG_VTTBR_EL2 = 0xe108,
+};
+
+static inline hv_return_t hv_vm_config_get_el2_supported(bool *el2_supported)
+{
+    g_assert_not_reached();
+}
+
+static inline hv_return_t hv_vm_config_set_el2_enabled(hv_vm_config_t config,
+                                                       bool el2_enabled)
+{
+    g_assert_not_reached();
+}
