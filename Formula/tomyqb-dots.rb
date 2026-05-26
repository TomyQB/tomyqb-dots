class TomyqbDots < Formula
  desc "Personal dotfiles installer for TomyQB development environment"
  homepage "https://github.com/TomyQB/tomyqb-dots"
  url "https://github.com/TomyQB/tomyqb-dots/archive/refs/tags/v0.2.12.tar.gz"
  sha256 "40f0c8047102c0470c9811524de25f702b87515868fad783ad7a5a2515baf228"
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
