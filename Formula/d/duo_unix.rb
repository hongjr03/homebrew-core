class DuoUnix < Formula
  desc "Two-factor authentication for SSH"
  homepage "https://www.duosecurity.com/docs/duounix"
  url "https://github.com/duosecurity/duo_unix/archive/refs/tags/duo_unix-2.3.0.tar.gz"
  sha256 "f8c53a1beb54f40765c1f5708a6cf6fd4abd94c645d5fdc52e222223d2040092"
  license "GPL-2.0-or-later"

  bottle do
    sha256               arm64_tahoe:   "76285c5a46ff71f3d834c49b7c4ecc96daa7141c03a272c62b56e8be8de28e18"
    sha256               arm64_sequoia: "4d4ad2acc77052130723256349822836d7046ade8c8759753ce5c6ce12aa4d81"
    sha256               arm64_sonoma:  "ed3201349e3aa724d05e121ea58643c7a272eb5705ac3c68802b05f784e82e9d"
    sha256 cellar: :any, sonoma:        "dc2def25dde741ed3a88deb37d6b864079f21e0c59a94d56a248e754c5336cb6"
    sha256               arm64_linux:   "dde0bca5fbf5c159f16571f85545240787e67b156eab72b148c9d89a076e28e8"
    sha256               x86_64_linux:  "e6b732ccd3f10ab695925616ef0b031454eec757e5b9fe7c2d854254f30db884"
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "openssl@3"

  on_linux do
    depends_on "linux-pam"
  end

  def install
    File.write("build-date", time.to_i)
    system "./bootstrap"
    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}",
                          "--sysconfdir=#{etc}",
                          "--includedir=#{include}/duo",
                          "--with-openssl=#{formula_opt_prefix("openssl@3")}",
                          "--with-pam=#{lib}/pam/"
    system "make", "install"
  end

  test do
    system sbin/"login_duo", "-d", "-c", "#{etc}/login_duo.conf",
                             "-f", "foobar", "echo", "SUCCESS"
  end
end
