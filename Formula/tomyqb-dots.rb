class TomyqbDots < Formula
  desc "Personal dotfiles installer for TomyQB development environment"
  homepage "https://github.com/TomyQB/tomyqb-dots"
  url "https://github.com/TomyQB/tomyqb-dots/archive/refs/tags/v0.2.21.tar.gz"
  sha256 "d28c61bc47b841d8f67b281431d785ad52cb571e9fe1495e32ac9745f1249805"
  license "MIT"
  head "https://github.com/TomyQB/tomyqb-dots.git", branch: "main"

  # Build dep so `brew bundle` is available when the user runs `tomyqb-dots install`.
  # (`brew bundle` ships with Homebrew core, but declaring it makes the dep explicit.)
  depends_on "bash"

  def install
    # Ship the whole repo (configs, Brewfile, install.sh) into libexec so the
    # installer can find them at a stable path relative to the bin entry point.
    libexec.install Dir["*"]

    # Drop a thin wrapper into the Homebrew bin/ that execs into libexec.
    (bin/"tomyqb-dots").write <<~SCRIPT
      #!/usr/bin/env bash
      exec "#{libexec}/bin/tomyqb-dots" "$@"
    SCRIPT
    (bin/"tomyqb-dots").chmod 0755
  end

  def caveats
    <<~EOS
      TomyQB.dots is installed. Apply it to your system with:
          tomyqb-dots install

      The installer will:
        • brew bundle the Brewfile (fish, starship, warp, aerospace, borders, ...)
        • Back up any existing configs to ~/.tomyqb-backup-<timestamp>/
        • Drop the dotfiles in place
        • Bootstrap fisher plugins
        • Set fish as your default shell
        • Start borders + AeroSpace

      You can re-run it any time — it's idempotent.
    EOS
  end

  test do
    assert_match "tomyqb-dots", shell_output("#{bin}/tomyqb-dots version")
  end
end
