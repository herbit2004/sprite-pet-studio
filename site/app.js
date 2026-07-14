const repository = "herbit2004/sprite-pet-studio";
const fallbackDownload = `https://github.com/${repository}/releases/latest/download/SpritePetStudio-macOS.zip`;

const formatBytes = (bytes) => {
  if (!Number.isFinite(bytes) || bytes <= 0) return "";
  const units = ["B", "KB", "MB", "GB"];
  const exponent = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / 1024 ** exponent;
  return `${value.toFixed(value >= 10 || exponent === 0 ? 0 : 1)} ${units[exponent]}`;
};

const updateRelease = async () => {
  document.querySelectorAll("[data-release-download]").forEach((link) => {
    link.href = fallbackDownload;
  });

  try {
    const response = await fetch(`https://api.github.com/repos/${repository}/releases/latest`, {
      headers: { Accept: "application/vnd.github+json" },
    });
    if (!response.ok) return;

    const release = await response.json();
    const archive = release.assets?.find((asset) => asset.name === "SpritePetStudio-macOS.zip");
    document.querySelectorAll("[data-version]").forEach((node) => {
      node.textContent = release.tag_name || "v0.1.0";
    });
    if (archive?.browser_download_url) {
      document.querySelectorAll("[data-release-download]").forEach((link) => {
        link.href = archive.browser_download_url;
      });
      const size = formatBytes(archive.size);
      document.querySelectorAll("[data-size]").forEach((node) => {
        node.textContent = size;
      });
    }
  } catch {
    // The stable latest-release URL remains usable if the API is unavailable.
  }
};

const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("is-visible");
      revealObserver.unobserve(entry.target);
    });
  },
  { rootMargin: "0px 0px -8%", threshold: 0.08 },
);

document.querySelectorAll(".reveal").forEach((element) => revealObserver.observe(element));
document.querySelectorAll("[data-year]").forEach((node) => {
  node.textContent = new Date().getFullYear();
});

updateRelease();
