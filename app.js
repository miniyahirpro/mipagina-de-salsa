(() => {
  const data = window.VIDEO_LIBRARY;

  const homeView = document.getElementById("home-view");
  const collectionsView = document.getElementById("collections-view");
  const collectionView = document.getElementById("collection-view");
  const liveView = document.getElementById("live-view");

  const goToCollections = document.getElementById("go-to-collections");
  const goToLive = document.getElementById("go-to-live");
  const homeCollectionsMeta = document.getElementById("home-collections-meta");
  const backHomeFromCollections = document.getElementById("back-home-from-collections");
  const backHomeFromLive = document.getElementById("back-home-from-live");

  const collectionsGrid = document.getElementById("collections-grid");
  const collectionSearch = document.getElementById("collection-search");
  const totalCollections = document.getElementById("total-collections");
  const totalVideos = document.getElementById("total-videos");

  const backButton = document.getElementById("back-to-collections");
  const collectionTitle = document.getElementById("collection-title");
  const collectionDescription = document.getElementById("collection-description");
  const collectionCount = document.getElementById("collection-count");
  const collectionCoverImage = document.getElementById("collection-cover-image");
  const collectionCoverFallback = document.getElementById("collection-cover-fallback");
  const videoSearch = document.getElementById("video-search");
  const collectionVideos = document.getElementById("collection-videos");
  const viewGridButton = document.getElementById("view-grid");
  const viewListButton = document.getElementById("view-list");

  const normalize = (value) =>
    (value || "")
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "");

  const clip = (text, max = 140) => {
    const clean = (text || "").trim();
    if (clean.length <= max) return clean;
    return `${clean.slice(0, max - 3).trim()}...`;
  };

  const getCollectionSummary = (name, videos) => {
    const key = normalize(name);
    const presets = [
      {
        rule: /salsa en parejas basico/,
        text: "Ruta inicial con bases claras para empezar salsa en pareja."
      },
      {
        rule: /salsa en parejas intermedio/,
        text: "Combinaciones intermedias y transiciones de mayor complejidad en pareja."
      },
      {
        rule: /salsa en parejas avanzado/,
        text: "Material avanzado con giros, tecnica y secuencias completas."
      },
      {
        rule: /bachata en parejas basico/,
        text: "Bachata desde cero: ritmo, base y figuras fundamentales."
      },
      {
        rule: /bachata en parejas inter/,
        text: "Combinaciones de bachata con mayor fluidez, tecnica y control de pareja."
      },
      {
        rule: /pasos libres/,
        text: "Entrenamiento de shines y musicalidad para reforzar estilo y control."
      },
      {
        rule: /party pack/,
        text: "Contenido social con merengue, cumbia y dinamicas de pista."
      }
    ];

    for (const preset of presets) {
      if (preset.rule.test(key)) {
        return preset.text;
      }
    }

    const sample = videos
      .map((video) => video.title || "")
      .filter((title) => title && normalize(title) !== "sin titulo")
      .slice(0, 2)
      .join(" | ");

    if (sample) {
      return clip(sample, 150);
    }

    return `Coleccion con ${videos.length} videos organizados por nivel y tematica.`;
  };

  const getCoverVideo = (videos) => videos.find((video) => video.thumbnailUrl) || videos[0] || null;

  if (!data || !Array.isArray(data.collections) || !collectionsGrid || !homeView || !liveView) {
    if (collectionsGrid) {
      collectionsGrid.innerHTML = '<div class="empty-state">No se encontro la data de videos.</div>';
    }
    return;
  }

  const collections = data.collections.map((collection, index) => {
    const coverVideo = getCoverVideo(collection.videos || []);
    return {
      id: `collection-${index + 1}`,
      name: collection.name,
      videos: collection.videos || [],
      count: (collection.videos || []).length,
      coverUrl: coverVideo?.thumbnailUrl || "",
      summary: getCollectionSummary(collection.name, collection.videos || [])
    };
  });

  const totalVideoCount = data.totalVideos || collections.reduce((sum, item) => sum + item.count, 0);

  const state = {
    collectionQuery: "",
    selectedCollectionId: null,
    videoQuery: "",
    postsView: "grid"
  };

  const getSelectedCollection = () =>
    collections.find((collection) => collection.id === state.selectedCollectionId) || null;

  const hideAllViews = () => {
    homeView.classList.add("is-hidden");
    collectionsView.classList.add("is-hidden");
    collectionView.classList.add("is-hidden");
    liveView.classList.add("is-hidden");
  };

  const showHomeView = () => {
    hideAllViews();
    homeView.classList.remove("is-hidden");
    window.scrollTo(0, 0);
  };

  const showCollectionsView = () => {
    state.selectedCollectionId = null;
    hideAllViews();
    collectionsView.classList.remove("is-hidden");
    renderCollections();
    window.scrollTo(0, 0);
  };

  const showLiveView = () => {
    hideAllViews();
    liveView.classList.remove("is-hidden");
    window.scrollTo(0, 0);
  };

  const showCollectionDetailView = (collectionId) => {
    state.selectedCollectionId = collectionId;
    state.videoQuery = "";
    state.postsView = "grid";
    videoSearch.value = "";
    viewGridButton.classList.add("is-active");
    viewListButton.classList.remove("is-active");

    const selected = getSelectedCollection();
    if (!selected) {
      showCollectionsView();
      return;
    }

    collectionTitle.textContent = selected.name;
    collectionDescription.textContent = selected.summary;
    collectionCount.textContent = `${selected.count} posts`;
    if (selected.coverUrl) {
      collectionCoverImage.src = selected.coverUrl;
      collectionCoverImage.alt = `Portada de ${selected.name}`;
      collectionCoverImage.classList.remove("is-hidden");
      collectionCoverFallback.classList.add("is-hidden");
    } else {
      collectionCoverImage.src = "";
      collectionCoverImage.classList.add("is-hidden");
      collectionCoverFallback.classList.remove("is-hidden");
    }

    hideAllViews();
    collectionView.classList.remove("is-hidden");
    renderCollectionPosts();
    window.scrollTo(0, 0);
  };

  const getFilteredCollections = () => {
    const query = normalize(state.collectionQuery);
    if (!query) return collections;

    return collections.filter((collection) => {
      const searchable = normalize(`${collection.name} ${collection.summary}`);
      return searchable.includes(query);
    });
  };

  const buildCollectionCard = (collection) => {
    const article = document.createElement("article");
    article.className = "collection-card";

    const openButton = document.createElement("button");
    openButton.type = "button";
    openButton.className = "collection-card-button";
    openButton.addEventListener("click", () => showCollectionDetailView(collection.id));

    const media = document.createElement("div");
    media.className = "collection-card-media";
    if (collection.coverUrl) {
      const image = document.createElement("img");
      image.src = collection.coverUrl;
      image.alt = `Portada ${collection.name}`;
      image.loading = "lazy";
      media.appendChild(image);
    } else {
      const fallback = document.createElement("div");
      fallback.className = "collection-card-fallback";
      fallback.textContent = "Sin portada";
      media.appendChild(fallback);
    }

    const countBadge = document.createElement("span");
    countBadge.className = "collection-card-count";
    countBadge.textContent = `${collection.count} videos`;
    media.appendChild(countBadge);
    openButton.appendChild(media);

    const content = document.createElement("div");
    content.className = "collection-card-content";

    const title = document.createElement("h3");
    title.className = "collection-card-title";
    title.textContent = collection.name;

    const description = document.createElement("p");
    description.className = "collection-card-description";
    description.textContent = clip(collection.summary, 132);

    content.appendChild(title);
    content.appendChild(description);
    openButton.appendChild(content);
    article.appendChild(openButton);

    return article;
  };

  const renderCollections = () => {
    const filtered = getFilteredCollections();
    collectionsGrid.innerHTML = "";

    if (!filtered.length) {
      collectionsGrid.innerHTML = '<div class="empty-state">No hay colecciones con ese filtro.</div>';
      return;
    }

    for (const collection of filtered) {
      collectionsGrid.appendChild(buildCollectionCard(collection));
    }
  };

  const getFilteredVideos = (collection) => {
    const query = normalize(state.videoQuery);

    return collection.videos.filter((video) => {
      if (!query) {
        return true;
      }

      const searchable = normalize(`${video.title} ${video.description}`);
      return searchable.includes(query);
    });
  };

  const buildVideoCard = (video) => {
    const article = document.createElement("article");
    article.className = "post-card";

    const watchUrl = video.watchUrl || video.postUrl || "#";
    const thumbLink = document.createElement("a");
    thumbLink.className = "post-thumb";
    thumbLink.href = watchUrl;
    if (watchUrl === "#") {
      thumbLink.setAttribute("aria-disabled", "true");
      thumbLink.addEventListener("click", (event) => event.preventDefault());
    }

    if (video.thumbnailUrl) {
      const image = document.createElement("img");
      image.src = video.thumbnailUrl;
      image.alt = `Miniatura de ${video.title}`;
      image.loading = "lazy";
      thumbLink.appendChild(image);
    } else {
      const fallback = document.createElement("div");
      fallback.className = "post-thumb-fallback";
      fallback.textContent = "Sin miniatura";
      thumbLink.appendChild(fallback);
    }

    const badge = document.createElement("span");
    badge.className = "post-badge";
    badge.textContent = "YouTube";
    thumbLink.appendChild(badge);

    const playIcon = document.createElement("span");
    playIcon.className = "post-play";
    playIcon.textContent = "Open";
    thumbLink.appendChild(playIcon);

    const title = document.createElement("h4");
    title.className = "post-title";
    title.textContent = video.title || "Sin titulo";

    const description = document.createElement("p");
    description.className = "post-description";
    description.textContent = clip(video.description || video.title || "Sin descripcion", 110);

    article.appendChild(thumbLink);
    article.appendChild(title);
    article.appendChild(description);

    return article;
  };

  const renderCollectionPosts = () => {
    const selected = getSelectedCollection();
    if (!selected) {
      return;
    }

    const filteredVideos = getFilteredVideos(selected);
    collectionCount.textContent =
      filteredVideos.length === selected.count
        ? `${selected.count} posts`
        : `${filteredVideos.length} de ${selected.count} posts`;

    collectionVideos.className = state.postsView === "list" ? "posts-list" : "posts-grid";
    collectionVideos.innerHTML = "";

    if (!filteredVideos.length) {
      collectionVideos.innerHTML = '<div class="empty-state">No hay videos con ese filtro.</div>';
      return;
    }

    for (const video of filteredVideos) {
      collectionVideos.appendChild(buildVideoCard(video));
    }
  };

  totalCollections.textContent = `${collections.length} colecciones`;
  totalVideos.textContent = `${totalVideoCount} videos`;
  homeCollectionsMeta.textContent = `${collections.length} colecciones | ${totalVideoCount} videos`;

  goToCollections.addEventListener("click", showCollectionsView);
  goToLive.addEventListener("click", showLiveView);
  backHomeFromCollections.addEventListener("click", showHomeView);
  backHomeFromLive.addEventListener("click", showHomeView);

  collectionSearch.addEventListener("input", (event) => {
    state.collectionQuery = event.target.value || "";
    renderCollections();
  });

  backButton.addEventListener("click", showCollectionsView);

  videoSearch.addEventListener("input", (event) => {
    state.videoQuery = event.target.value || "";
    renderCollectionPosts();
  });

  viewGridButton.addEventListener("click", () => {
    state.postsView = "grid";
    viewGridButton.classList.add("is-active");
    viewListButton.classList.remove("is-active");
    renderCollectionPosts();
  });

  viewListButton.addEventListener("click", () => {
    state.postsView = "list";
    viewListButton.classList.add("is-active");
    viewGridButton.classList.remove("is-active");
    renderCollectionPosts();
  });

  showHomeView();
})();
