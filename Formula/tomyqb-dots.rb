class TomyqbDots < Formula
  desc "Personal dotfiles installer for TomyQB development environment"
  homepage "https://github.com/TomyQB/tomyqb-dots"
  url "https://github.com/TomyQB/tomyqb-dots/archive/refs/tags/v0.2.7.tar.gz"
  sha256 "24fd6c7d8e0ee55ff2fa5dcb0367b1fda77089f0c441a0e40d9d8f5c0ef3a965"
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
        • brew bundle the Brewfile (fish, starship, ghostty, aerospace, borders, ...)
        • Back up any existing configs to ~/.tomyqb-backup-<timestamp>/
        • Drop the dotfiles in place
        • Bootstrap fisher + tpm plugins
        • Set fish as your default shell
        • Start borders + AeroSpace

      You can re-run it any time — it's idempotent.
    EOS
  end

  test do
    assert_match "tomyqb-dots", shell_output("#{bin}/tomyqb-dots version")
  end
end
