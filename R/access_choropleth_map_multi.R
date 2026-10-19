#' Multi-geography "closest provider" access choropleth, with full control panel
#'
#' @description
#' Same idea as [mysterymaps_access_choropleth_map()] but for SEVERAL
#' geographies switchable in one map (e.g. county AND congressional
#' district). Each geography contributes a drive-time shading, a supply
#' shading, an optional coverage shading, a legend set, a hover-labelled
#' access-desert overlay, and click-to-highlight; providers and the search
#' box are shared across every geography. A collapsible control panel (top
#' right) drives geography/metric/basemap selection, an optional zoom-to-ZIP
#' box, a reset-to-CONUS button, geolocate, print, and a worst-access
#' quick-list; state round-trips through the URL hash for shareable links.
#'
#' @section A sibling, not a duplicate, of `mysterymaps_county_access_map()`:
#' See the section of the same name on [mysterymaps_access_choropleth_map()]
#' -- this function is the multi-geography extension of that one, not a
#' third, competing template.
#'
#' @param geos Named list; each element a list with `sf` (carrying the
#'   `mm_*` columns documented in [mysterymaps_access_choropleth_map()], plus
#'   optional `mm_fill_coverage`, `mm_hover`, `mm_hover_supply`,
#'   `mm_hover_coverage`), `supply_pal`, `supply_values`, and optional
#'   `time_legend`, `supply_legend`, `coverage_pal`, `coverage_values`,
#'   `coverage_legend`, `desert`. **`mm_id` must be unique across every
#'   geography combined, not just within one** -- every polygon's layerId
#'   shares one leaflet layer registry for the whole map, and this function
#'   errors rather than silently cross-wiring click-to-highlight if two
#'   geographies share an id. Names become the geography labels shown in
#'   the control panel. The first geography is shown by default.
#' @param providers `sf` POINTs (`mm_id`, `mm_label`, `mm_popup`), shared
#'   across every geography.
#' @param highlight_lookup Named list merging every geography's geo-id ->
#'   provider-id vectors (ids must be unique across geographies).
#' @param band_colors,band_labels,title_html,base_tiles As in
#'   [mysterymaps_access_choropleth_map()].
#' @param dark_tiles `character(1)`: provider-tile name for the dark basemap
#'   option. Default `"CartoDB.DarkMatter"`, toggled from the control panel's
#'   Basemap switch.
#' @param provider_fill Fill colour (or a leaflet formula, e.g. `~mm_fill`)
#'   for the shared provider markers.
#' @param coverage_by_geo Optional named list (geography name -> HTML
#'   string); the control panel shows the entry for the active geography and
#'   updates it when the geography changes.
#' @param band_counts_by_geo Optional named list (geography name -> integer
#'   vector aligned to `band_labels`); appended as counts to the drive-time
#'   legend for that geography.
#' @param centroids_by_geo Optional named list (geography name -> `sf`
#'   POINTs); each geography's scoring anchor point, shown as an optional
#'   overlay toggle. Makes the aggregation explicit -- e.g. why a large
#'   district reads a slow band even with a provider inside it, when the
#'   anchor point sits elsewhere.
#' @param worst_by_geo Optional named list (geography name -> data frame with
#'   `label`, `lat`, `lon`, optional `note`); rendered as a click-to-zoom
#'   "worst access" quick-list in the control panel.
#' @param iso_union Optional `sf` with a `band` column: nested drive-time
#'   union polygons (any set of bands; drawn widest-first, in descending
#'   `band` order), toggled as an "Isochrone reach" overlay. `NULL` omits it.
#' @param zip_centroids Optional data frame with `zip`, `lat`, `lon` columns;
#'   powers the client-side zoom-to-ZIP box (embedded as a compact lookup, no
#'   external geocoder). `NULL` hides the box.
#' @param conus_bounds Numeric `c(west, south, east, north)` used for the
#'   initial frame and the reset-view button (default lower-48).
#' @param provider_noun `character(1)`: singular noun for what a provider
#'   is, used in the isochrone-band labels (e.g. `"Reachable within 30 min
#'   of a <provider_noun>"`). Default `"provider"`. A caller mapping a
#'   specific specialty passes e.g. `"urogynecologist"`.
#' @param aria_label `character(1)` or `NULL`: the map container's
#'   `aria-label`, for assistive tech. Default `NULL`, which falls back to
#'   `sprintf("Interactive map of access to %ss", provider_noun)`.
#' @param desert_tooltip `character(1)` or `NULL`: tooltip text on the
#'   no-access legend swatch. Default `NULL`, which falls back to
#'   `sprintf("purple outline = no %s in range", provider_noun)`.
#' @param coverage_metric_label `character(1)` or `NULL`: label for the
#'   "Shade by: coverage" radio button, shown only when a geography carries
#'   `mm_fill_coverage`. Default `NULL`, which falls back to `"Coverage"`.
#' @param centroid_label `character(1)`: heading used for the
#'   `centroids_by_geo` toggle and its marker popups. Default
#'   `"Analysis point"`.
#' @return A `leaflet` htmlwidget.
#' @family mapping
#' @seealso [mysterymaps_county_access_map()], [mysterymaps_access_choropleth_map()]
#' @export
mysterymaps_access_choropleth_map_multi <- function(geos, providers, highlight_lookup,
                                                     band_colors, band_labels, title_html,
                                                     base_tiles = "CartoDB.Positron",
                                                     dark_tiles = "CartoDB.DarkMatter",
                                                     provider_fill = "#3b0a45",
                                                     coverage_by_geo = NULL,
                                                     band_counts_by_geo = NULL,
                                                     centroids_by_geo = NULL,
                                                     worst_by_geo = NULL,
                                                     iso_union = NULL,
                                                     zip_centroids = NULL,
                                                     conus_bounds = c(-125, 24.4, -66.9, 49.4),
                                                     provider_noun = "provider",
                                                     aria_label = NULL,
                                                     desert_tooltip = NULL,
                                                     coverage_metric_label = NULL,
                                                     centroid_label = "Analysis point") {
  for (pkg in c("sf", "leaflet", "leaflet.extras", "htmltools", "htmlwidgets")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("mysterymaps_access_choropleth_map_multi() needs the '", pkg,
           "' package, which is a Suggests dependency. Install it to use ",
           "this function.", call. = FALSE)
    }
  }
  checkmate::assert_list(geos, names = "unique")
  checkmate::assert_class(providers, "sf")
  checkmate::assert_string(provider_noun)
  checkmate::assert_string(centroid_label)
  stopifnot(length(geos) >= 1, !is.null(names(geos)))

  aria_label <- aria_label %||% sprintf("Interactive map of access to %ss", provider_noun)
  desert_tooltip <- desert_tooltip %||% sprintf("purple outline = no %s in range", provider_noun)

  # ZIP -> [lat, lon] lookup for the zoom-to-ZIP box (client-side, no geocoder).
  # A compact named list serializes to {"80202":[39.75,-104.99], ...}; rounding
  # to 3 decimals (~110 m) keeps it small and is plenty to frame a ZIP.
  zip_lookup <- NULL
  if (!is.null(zip_centroids) && nrow(zip_centroids)) {
    z <- zip_centroids[stats::complete.cases(zip_centroids[, c("zip", "lat", "lon")]), ]
    # as.integer() on a non-numeric ZIP (e.g. ZIP+4, "80202-1234") returns NA
    # with a warning rather than failing -- sprintf("%05d", NA) then names the
    # lookup entry the literal string "NA" rather than dropping it, which is
    # worse than silent: it looks like a real, searchable key. complete.cases()
    # above does not catch this -- the raw zip string is never NA, only its
    # parsed form is. Validated as plain digits BEFORE parsing, so a malformed
    # entry is dropped instead of becoming a key.
    valid <- grepl("^[0-9]{1,5}$", trimws(as.character(z$zip)))
    z <- z[valid, , drop = FALSE]
    zip_lookup <- stats::setNames(
      Map(function(la, lo) c(round(la, 3), round(lo, 3)), z$lat, z$lon),
      sprintf("%05d", as.integer(z$zip)))
  }
  req <- c("mm_id", "mm_label", "mm_popup", "mm_fill_time", "mm_fill_supply", "mm_no_access")
  mm_assert_unique_geo_ids(geos, "mysterymaps_access_choropleth_map_multi")
  mm_assert_unique_provider_ids(providers, "mysterymaps_access_choropleth_map_multi")
  # leaflet expects WGS84 lon/lat (see mysterymaps_access_choropleth_map()'s
  # own comment on this); reproject defensively rather than trust every
  # geography and the provider layer already arrived in 4326.
  providers <- sf::st_transform(providers, 4326)
  geos <- lapply(geos, function(g) {
    g$sf <- sf::st_transform(g$sf, 4326)
    g
  })

  old_s2 <- sf::sf_use_s2(); sf::sf_use_s2(FALSE); on.exit(sf::sf_use_s2(old_s2), add = TRUE)
  tok <- function(x) gsub("[^A-Za-z0-9]", "", x)
  esc <- function(x) htmltools::htmlEscape(x)
  geo_names <- names(geos)
  centroid_tpl <- sprintf("<b>%s</b><br>%%s", centroid_label)  # nolint: object_usage_linter. used inside a ~lapply(sprintf(centroid_tpl, ...)) formula below
  has_cov <- any(vapply(geos, function(g) "mm_fill_coverage" %in% names(g$sf), logical(1)))
  mm_assert_coverage_pal(geos, "mysterymaps_access_choropleth_map_multi")
  has_iso <- !is.null(iso_union) && nrow(iso_union) > 0

  # ---- control panel HTML (two-axis geography x metric, basemap, toggles) ----
  geo_radio <- paste0(vapply(seq_along(geo_names), function(i) sprintf(
    "<label class='mmp-opt'><input type='radio' name='mmp-geo' value='%s'%s> %s</label>",
    esc(geo_names[i]), if (i == 1) " checked" else "", esc(geo_names[i])), character(1)), collapse = "")
  panel_html <- paste0(
    "<style>",
    ".leaflet-control-layers{display:none !important;}",
    ".mmp{background:rgba(255,255,255,.96);padding:7px 10px;border-radius:6px;",
    "font:12px/1.4 sans-serif;box-shadow:0 1px 4px rgba(0,0,0,.3);min-width:158px;max-width:270px;}",
    # collapsible header + height-capped scrolling body so the panel never covers the map
    ".mmp-hd{display:flex;align-items:center;justify-content:space-between;cursor:pointer;",
    "user-select:none;font-weight:700;font-size:11px;color:#333;}",
    ".mmp-chev{font-size:10px;color:#888;transition:transform .15s ease;}",
    ".mmp.collapsed .mmp-chev{transform:rotate(-90deg);}",
    ".mmp.collapsed{min-width:0;}",
    ".mmp-body{max-height:min(64vh,560px);overflow-y:auto;margin-top:6px;padding-right:2px;}",
    ".mmp.collapsed .mmp-body{display:none;}",
    ".mmp-sec{margin-bottom:7px;} .mmp-sec:last-child{margin-bottom:0;}",
    ".mmp-h{font-weight:700;font-size:10px;color:#555;margin-bottom:3px;",
    "text-transform:uppercase;letter-spacing:.03em;}",
    ".mmp-opt{display:block;cursor:pointer;padding:1px 0;} .mmp-opt input{margin-right:5px;}",
    ".mmp-cov{margin-top:2px;font-size:11px;color:#555;border-top:1px solid #eee;padding-top:5px;}",
    ".mmp-worst{margin:2px 0 0;padding:0 0 0 18px;font-size:11px;max-height:128px;overflow-y:auto;}",
    ".mmp-worst li{margin:1px 0;}",
    ".mmp-worst a{color:#2166ac;text-decoration:none;} .mmp-worst a:hover{text-decoration:underline;}",
    ".mmp-worst-note{color:#999;}",
    ".mmp-tools{display:flex;flex-direction:column;gap:5px;}",
    ".mmp-btn{width:32px;height:32px;font-size:16px;line-height:1;background:#fff;border:1px solid #ccc;",
    "border-radius:4px;cursor:pointer;box-shadow:0 1px 3px rgba(0,0,0,.25);} .mmp-btn:hover{background:#f0f0f0;}",
    "@media (max-width:760px){.mmp{max-width:calc(100vw - 90px);} .mmp-body{max-height:52vh;}}",
    # (#4) zoom-to-ZIP input
    ".mmp-zip{width:100%;box-sizing:border-box;padding:3px 5px;border:1px solid #ccc;",
    "border-radius:4px;font:12px sans-serif;} .mmp-zip-msg{font-size:10px;color:#c0392b;margin-top:2px;min-height:12px;}",
    # (#3) desert-overlay legend swatch: a hollow purple outline, matching the map
    ".mmp-swatch{display:inline-block;width:11px;height:11px;border:2px solid #7a0177;",
    "background:transparent;vertical-align:middle;margin-left:3px;border-radius:2px;}",
    # (#5) visible keyboard focus + skip-to-map affordance
    ".mmp-opt input:focus-visible,.mmp-btn:focus-visible,.mmp-zip:focus-visible,",
    "#mmp-hd:focus-visible,.mmp-skip:focus-visible{outline:2px solid #2166ac;outline-offset:1px;}",
    ".mmp-skip{position:absolute;left:8px;top:-42px;z-index:1200;background:#2166ac;color:#fff;",
    "padding:8px 12px;border-radius:4px;font:13px sans-serif;text-decoration:none;transition:top .12s ease;}",
    ".mmp-skip:focus{top:8px;}",
    # (#2) print / save-as-PDF: hide the chrome, let the map fill the page
    "@media print{.mmp,.mmp-tools,.mmp-skip,.leaflet-control-layers,.leaflet-control-search,",
    ".leaflet-control-zoom,.leaflet-control-attribution{display:none !important;}}",
    "</style>",
    "<div class='mmp' role='region' aria-label='Map controls'>",
    "<div class='mmp-hd' id='mmp-hd' role='button' tabindex='0' aria-expanded='true' aria-controls='mmp-body'>",
    "<span>Map controls</span><span class='mmp-chev' aria-hidden='true'>&#9660;</span></div>",
    "<div class='mmp-body' id='mmp-body'>",
    if (!is.null(zip_lookup))
      paste0("<div class='mmp-sec'><div class='mmp-h'>Find a ZIP code</div>",
             "<input type='text' inputmode='numeric' maxlength='5' class='mmp-zip' id='mmp-zip' ",
             "placeholder='e.g. 80202' aria-label='Zoom to a ZIP code'>",
             "<div class='mmp-zip-msg' id='mmp-zip-msg' role='status' aria-live='polite'></div></div>") else "",
    "<div class='mmp-sec'><div class='mmp-h'>Geography</div>", geo_radio, "</div>",
    "<div class='mmp-sec'><div class='mmp-h'>Shade by</div>",
    "<label class='mmp-opt'><input type='radio' name='mmp-metric' value='drive time' checked> Drive time</label>",
    "<label class='mmp-opt'><input type='radio' name='mmp-metric' value='supply'> Supply</label>",
    if (has_cov) sprintf("<label class='mmp-opt'><input type='radio' name='mmp-metric' value='coverage'> %s</label>",
                         coverage_metric_label %||% "Coverage") else "",
    "</div>",
    "<div class='mmp-sec'><div class='mmp-h'>Basemap</div>",
    "<label class='mmp-opt'><input type='radio' name='mmp-base' value='light' checked> Light</label>",
    "<label class='mmp-opt'><input type='radio' name='mmp-base' value='dark'> Dark</label></div>",
    "<div class='mmp-sec'>",
    "<label class='mmp-opt'><input type='checkbox' id='mmp-prov' checked> Providers</label>",
    "<label class='mmp-opt'><input type='checkbox' id='mmp-na'> Highlight no-access",
    sprintf("<span class='mmp-swatch' aria-hidden='true' title='%s'></span></label>", desert_tooltip),
    if (!is.null(centroids_by_geo))
      sprintf("<label class='mmp-opt'><input type='checkbox' id='mmp-cent'> %s</label>", centroid_label) else "",
    if (has_iso)
      "<label class='mmp-opt'><input type='checkbox' id='mmp-iso'> Isochrone reach (drive-time union)</label>" else "",
    "</div>",
    if (!is.null(coverage_by_geo)) "<div class='mmp-cov' id='mmp-cov'></div>" else "",
    if (!is.null(worst_by_geo))
      paste0("<div class='mmp-sec' style='margin-top:6px;border-top:1px solid #eee;",
             "padding-top:5px'><div class='mmp-h'>Worst access (click to zoom)</div>",
             "<ol class='mmp-worst' id='mmp-worst'></ol></div>") else "",
    "</div></div>")   # close .mmp-body, then .mmp
  tools_html <- paste0(
    "<a href='#' class='mmp-skip' id='mmp-skip'>Skip to map</a>",
    "<div class='mmp-tools'>",
    "<button id='mmp-home' class='mmp-btn' title='Reset to CONUS' aria-label='Reset view to the continental United States'>&#8962;</button>",
    "<button id='mmp-loc' class='mmp-btn' title='Zoom to my location' aria-label='Zoom to my location'>&#9678;</button>",
    "<button id='mmp-print' class='mmp-btn' title='Print or save as PDF' aria-label='Print or save this map as PDF'>&#128424;</button>",
    "</div>")

  combined_js <- r"---(
function(el, x, data) {
  var map = this;
  /* (#5) name the map region for assistive tech */
  try { var _mc = map.getContainer(); _mc.setAttribute("role", "region");
        _mc.setAttribute("aria-label", data.ariaLabel || "Interactive map"); } catch (e) {}
  var lookup    = data.lookup    || {};
  var defGeo    = data.defGeo    || "";
  var geoNames  = data.geoNames  || [];
  var cov       = data.coverage  || {};
  var CB        = data.conus     || null;
  var worst     = data.worst     || {};   // worst-access quick-list per geography
  var zips      = data.zips      || {};   // ZIP -> [lat, lon] for the find-a-ZIP box
  var lit = [];

  /* --- legend toggle (driven by native baselayerchange) ------------------ */
  function showLeg(groupName) {
    var t = groupName.replace(/[^A-Za-z0-9]/g, "");
    el.querySelectorAll(".leg").forEach(function(l) { l.style.display = "none"; });
    var e = el.querySelector(".leg-" + t);
    if (e) e.style.display = "";
  }
  map.on("baselayerchange", function(ev) { showLeg(ev.name); });

  /* --- proxy the hidden native layers control ---------------------------- */
  function clickBaseByName(name) {
    el.querySelectorAll(".leaflet-control-layers-base label").forEach(function(lab) {
      if (lab.textContent.trim() === name) {
        var i = lab.querySelector("input"); if (i && !i.checked) i.click();
      }
    });
  }
  function setOverlayByName(name, on) {
    el.querySelectorAll(".leaflet-control-layers-overlays label").forEach(function(lab) {
      if (lab.textContent.trim() === name) {
        var i = lab.querySelector("input"); if (i && i.checked !== on) i.click();
      }
    });
  }

  var st = { geo: (geoNames[0] || defGeo), metric: "drive time", dark: false, providers: true, na: false, cent: false, iso: false };

  /* --- worst-access quick-list ------------------------------------------- */
  function renderWorst() {
    var ol = el.querySelector("#mmp-worst"); if (!ol) return;
    var rows = worst[st.geo] || [];
    if (!rows.length) { ol.innerHTML = "<li style='list-style:none;color:#999'>all areas covered</li>"; return; }
    ol.innerHTML = "";
    rows.forEach(function(r) {
      var li = document.createElement("li");
      var a = document.createElement("a");
      a.href = "#"; a.textContent = r.label;
      a.title = r.note || "";
      a.addEventListener("click", function(e) {
        e.preventDefault();
        if (r.lat != null && r.lon != null) map.setView([r.lat, r.lon], 8);
      });
      li.appendChild(a);
      if (r.note) { var s = document.createElement("span"); s.className = "mmp-worst-note"; s.textContent = " " + r.note; li.appendChild(s); }
      ol.appendChild(li);
    });
  }

  /* --- URL deep-linking (state <-> location.hash) ------------------------ */
  function writeHash() {
    var c = map.getCenter();
    var parts = ["g=" + encodeURIComponent(st.geo), "m=" + (st.metric === "supply" ? "s" : st.metric === "coverage" ? "c" : "d"),
      "b=" + (st.dark ? "dark" : "light"), "p=" + (st.providers ? 1 : 0), "n=" + (st.na ? 1 : 0),
      "a=" + (st.cent ? 1 : 0), "i=" + (st.iso ? 1 : 0), "z=" + map.getZoom(), "c=" + c.lat.toFixed(3) + "," + c.lng.toFixed(3)];
    try { history.replaceState(null, "", "#" + parts.join("&")); } catch (e) {}
  }
  function readHash() {
    var h = (location.hash || "").replace(/^#/, ""); if (!h) return null;
    var kv = {}; h.split("&").forEach(function(p) { var i = p.indexOf("="); if (i > 0) kv[p.slice(0, i)] = decodeURIComponent(p.slice(i + 1)); });
    if (kv.g && geoNames.indexOf(kv.g) >= 0) st.geo = kv.g;
    if (kv.m) st.metric = (kv.m === "s") ? "supply" : (kv.m === "c") ? "coverage" : "drive time";
    if (kv.b) st.dark = (kv.b === "dark");
    if (kv.p != null) st.providers = (kv.p === "1");
    if (kv.n != null) st.na = (kv.n === "1");
    if (kv.a != null) st.cent = (kv.a === "1");
    if (kv.i != null) st.iso = (kv.i === "1");
    return kv;
  }
  function syncPanel() {   // reflect st back into the panel controls after a hash restore
    el.querySelectorAll("input[name=mmp-geo]").forEach(function(r) { r.checked = (r.value === st.geo); });
    el.querySelectorAll("input[name=mmp-metric]").forEach(function(r) { r.checked = (r.value === st.metric); });
    el.querySelectorAll("input[name=mmp-base]").forEach(function(r) { r.checked = (r.value === (st.dark ? "dark" : "light")); });
    var pv = el.querySelector("#mmp-prov"); if (pv) pv.checked = st.providers;
    var na = el.querySelector("#mmp-na");   if (na) na.checked = st.na;
    var ct = el.querySelector("#mmp-cent"); if (ct) ct.checked = st.cent;
    var iso = el.querySelector("#mmp-iso"); if (iso) iso.checked = st.iso;
  }

  function apply() {
    clickBaseByName(st.geo + ": " + st.metric);
    setOverlayByName("Dark basemap", st.dark);
    setOverlayByName("Providers", st.providers);
    setOverlayByName("Isochrone reach", st.iso);
    geoNames.forEach(function(g) {
      setOverlayByName(g + ": no access", st.na && g === st.geo);
      setOverlayByName(g + ": centroid",  st.cent && g === st.geo);
    });
    var ce = el.querySelector("#mmp-cov"); if (ce) ce.innerHTML = cov[st.geo] || "";
    renderWorst();
    writeHash();
  }

  el.querySelectorAll("input[name=mmp-geo]").forEach(function(r) {
    r.addEventListener("change", function() { if (r.checked) { st.geo = r.value; apply(); } });
  });
  el.querySelectorAll("input[name=mmp-metric]").forEach(function(r) {
    r.addEventListener("change", function() { if (r.checked) { st.metric = r.value; apply(); } });
  });
  el.querySelectorAll("input[name=mmp-base]").forEach(function(r) {
    r.addEventListener("change", function() { if (r.checked) { st.dark = (r.value === "dark"); apply(); } });
  });
  var pv = el.querySelector("#mmp-prov"); if (pv) pv.addEventListener("change", function() { st.providers = pv.checked; apply(); });
  var na = el.querySelector("#mmp-na");   if (na) na.addEventListener("change", function() { st.na = na.checked; apply(); });
  var ct = el.querySelector("#mmp-cent"); if (ct) ct.addEventListener("change", function() { st.cent = ct.checked; apply(); });
  var iso = el.querySelector("#mmp-iso"); if (iso) iso.addEventListener("change", function() { st.iso = iso.checked; apply(); });
  map.on("moveend", writeHash);   // keep the shareable link's center/zoom current

  /* --- reset / geolocate buttons + initial frame ------------------------- */
  function home() { if (CB) map.fitBounds([[CB[1], CB[0]], [CB[3], CB[2]]]); }
  var hb = el.querySelector("#mmp-home"); if (hb) hb.addEventListener("click", function(e) { e.preventDefault(); home(); });
  var lb = el.querySelector("#mmp-loc");  if (lb) lb.addEventListener("click", function(e) { e.preventDefault(); map.locate({ setView: true, maxZoom: 9 }); });

  /* --- (#4) zoom-to-ZIP: client-side lookup, no external geocoder ---------- */
  var zipIn = el.querySelector("#mmp-zip"), zipMsg = el.querySelector("#mmp-zip-msg");
  function goZip() {
    if (!zipIn) return;
    var z = (zipIn.value || "").replace(/[^0-9]/g, "").slice(0, 5);
    if (z.length < 5) { if (zipMsg) zipMsg.textContent = ""; return; }
    var ll = zips[z];
    if (ll) { map.setView([ll[0], ll[1]], 9); if (zipMsg) zipMsg.textContent = ""; }
    else if (zipMsg) zipMsg.textContent = "ZIP " + z + " not found";
  }
  if (zipIn) {
    zipIn.addEventListener("keydown", function(e) { if (e.key === "Enter") { e.preventDefault(); goZip(); } });
    zipIn.addEventListener("input", function() { if (zipIn.value.replace(/[^0-9]/g, "").length === 5) goZip(); });
  }

  /* --- (#2) print / save as PDF ------------------------------------------- */
  var pb = el.querySelector("#mmp-print"); if (pb) pb.addEventListener("click", function(e) { e.preventDefault(); window.print(); });

  /* --- (#5) skip-to-map: move keyboard focus onto the map ----------------- */
  var skip = el.querySelector("#mmp-skip");
  if (skip) skip.addEventListener("click", function(e) {
    e.preventDefault();
    var c = map.getContainer();
    c.setAttribute("tabindex", "-1"); c.focus(); c.scrollIntoView({ block: "nearest" });
  });

  /* --- keep panel interactions off the map ------------------------------- */
  if (window.L && L.DomEvent) {
    ["mmp", "mmp-tools"].forEach(function(cls) {
      var n = el.querySelector("." + cls);
      if (n) { L.DomEvent.disableClickPropagation(n); L.DomEvent.disableScrollPropagation(n); }
    });
  }

  /* --- collapsible panel so it never covers the map ---------------------- */
  var panelEl = el.querySelector(".mmp");
  var hdEl = el.querySelector("#mmp-hd");
  function togglePanel() {
    if (!panelEl) return;
    var collapsed = panelEl.classList.toggle("collapsed");
    if (hdEl) hdEl.setAttribute("aria-expanded", collapsed ? "false" : "true");
  }
  if (hdEl && panelEl) {
    hdEl.addEventListener("click", togglePanel);
    hdEl.addEventListener("keydown", function(e) {   // (#5) keyboard-operable header
      if (e.key === "Enter" || e.key === " ") { e.preventDefault(); togglePanel(); }
    });
  }
  if (panelEl && window.matchMedia && window.matchMedia("(max-width: 760px)").matches) {
    panelEl.classList.add("collapsed");   // start collapsed on phones
    if (hdEl) hdEl.setAttribute("aria-expanded", "false");
  }

  /* --- click-to-highlight (unchanged behaviour) -------------------------- */
  function reset() {
    lit.forEach(function(mk) {
      mk.setRadius(3).setStyle({
        fillColor: mk._origFill || mk.options.fillColor,
        fillOpacity: 0.9, stroke: true, color: "#ffffff", weight: 1
      });
    });
    lit = [];
  }
  function light(ids) {
    reset();
    if (ids == null) ids = [];
    if (!Array.isArray(ids)) ids = [ids];
    ids.forEach(function(id) {
      var mk = map.layerManager.getLayer("marker", String(id));
      if (mk) {
        if (!mk._origFill) mk._origFill = mk.options.fillColor;
        mk.setRadius(8).setStyle({ fillColor: "#e6194B", fillOpacity: 1, stroke: true, color: "#ffffff", weight: 2 });
        mk.bringToFront();
        lit.push(mk);
      }
    });
  }
  Object.keys(lookup).forEach(function(g) {
    ["", "S_", "C_"].forEach(function(pfx) {
      var poly = map.layerManager.getLayer("shape", pfx + g);
      if (poly) { poly.on("click", function() { light(lookup[g]); }); }
    });
  });

  var hk = readHash();          // restore shared state before the first apply()
  syncPanel();
  showLeg(st.geo + ": " + st.metric);
  apply();
  if (hk && hk.c) {
    var cc = hk.c.split(",");
    if (cc.length === 2) map.setView([parseFloat(cc[0]), parseFloat(cc[1])], hk.z ? parseInt(hk.z, 10) : map.getZoom());
  }
}
)---"

  m <- leaflet::leaflet() |>
    leaflet::addProviderTiles(base_tiles) |>
    leaflet::addProviderTiles(dark_tiles, group = "Dark basemap") |>
    # live scale bar (miles + km, rescales with zoom); bottom-left is the only
    # free corner (title/tools top-left, panel top-right, legends bottom-right)
    leaflet::addScaleBar(position = "bottomleft",
                         options = leaflet::scaleBarOptions(imperial = TRUE, metric = TRUE))
  base_groups <- character(0); desert_groups <- character(0); centroid_groups <- character(0)
  for (gname in names(geos)) {
    g <- geos[[gname]]; gsf <- g$sf
    miss <- setdiff(req, names(gsf))
    if (length(miss)) stop("mysterymaps_access_choropleth_map_multi: geo '", gname, "' missing: ",
                           paste(miss, collapse = ", "), call. = FALSE)
    tgrp <- paste0(gname, ": drive time"); sgrp <- paste0(gname, ": supply")
    cvgrp <- paste0(gname, ": coverage")
    dgrp <- paste0(gname, ": no access")
    has_cov_g <- "mm_fill_coverage" %in% names(gsf)
    base_groups <- c(base_groups, tgrp, sgrp, if (has_cov_g) cvgrp)
    deserts <- gsf[which(as.logical(gsf$mm_no_access)), ]
    geo_pts <- suppressWarnings(sf::st_point_on_surface(gsf))
    dtxt <- if (is.null(g$desert)) "no provider in range" else g$desert  # nolint: object_usage_linter. used inside a ~lapply(sprintf(..., dtxt)) formula below
    hov <- if ("mm_hover" %in% names(gsf)) lapply(gsf$mm_hover, htmltools::HTML) else
      lapply(sprintf("<b>%s</b>", gsf$mm_label), htmltools::HTML)
    # metric-aware hover: supply/coverage layers show their own value, not drive time
    hov_supply <- if ("mm_hover_supply" %in% names(gsf)) lapply(gsf$mm_hover_supply, htmltools::HTML) else hov
    hov_cov <- if ("mm_hover_coverage" %in% names(gsf)) lapply(gsf$mm_hover_coverage, htmltools::HTML) else hov
    tlabels <- band_labels
    if (!is.null(band_counts_by_geo) && !is.null(band_counts_by_geo[[gname]])) {
      cnts <- band_counts_by_geo[[gname]]
      tlabels <- vapply(seq_along(band_labels), function(i) {
        if (i <= length(cnts) && !is.na(cnts[i]))
          sprintf("%s (%s)", band_labels[i], format(cnts[i], big.mark = ",")) else band_labels[i]
      }, character(1))
    }
    m <- m |>
      leaflet::addPolygons(data = gsf, fillColor = ~mm_fill_time, fillOpacity = 0.7, color = "#888",
        weight = 0.4, popup = ~mm_popup, label = hov, group = tgrp, layerId = ~mm_id,
        highlightOptions = leaflet::highlightOptions(weight = 2, color = "#000", bringToFront = TRUE)) |>
      leaflet::addPolygons(data = gsf, fillColor = ~mm_fill_supply, fillOpacity = 0.7, color = "#888",
        weight = 0.4, popup = ~mm_popup, label = hov_supply, group = sgrp, layerId = ~paste0("S_", mm_id),
        highlightOptions = leaflet::highlightOptions(weight = 2, color = "#000", bringToFront = TRUE))
    if (has_cov_g) {
      m <- m |> leaflet::addPolygons(data = gsf, fillColor = ~mm_fill_coverage, fillOpacity = 0.7, color = "#888",
        weight = 0.4, popup = ~mm_popup, label = hov_cov, group = cvgrp, layerId = ~paste0("C_", mm_id),
        highlightOptions = leaflet::highlightOptions(weight = 2, color = "#000", bringToFront = TRUE))
    }
    # Access-desert overlay only when there is at least one desert; adding a
    # zero-row polygon layer errors in leaflet's bbox expansion.
    if (nrow(deserts) > 0) {
      m <- m |>
        leaflet::addPolygons(data = deserts, fill = FALSE, color = "#7a0177", weight = 1.4, group = dgrp,
          label = ~lapply(sprintf("<b>%s</b> &mdash; %s", mm_label, dtxt), htmltools::HTML),
          highlightOptions = leaflet::highlightOptions(weight = 3, color = "#49006a", bringToFront = TRUE))
      desert_groups <- c(desert_groups, dgrp)
    }
    # Analysis-point overlay: the single centroid each area is scored from. Makes
    # the aggregation explicit (e.g. why a large district reads a slow band even
    # with a provider inside it -- the anchor point sits elsewhere). Hidden by default.
    if (!is.null(centroids_by_geo) && !is.null(centroids_by_geo[[gname]]) &&
        nrow(centroids_by_geo[[gname]]) > 0) {
      cgrp <- paste0(gname, ": centroid")
      m <- m |>
        leaflet::addCircleMarkers(data = centroids_by_geo[[gname]], radius = 6,
          color = "#000000", weight = 2, stroke = TRUE, fill = TRUE,
          fillColor = "#ffffff", fillOpacity = 0.85, group = cgrp,
          label = ~lapply(sprintf(centroid_tpl, mm_label), htmltools::HTML))
      centroid_groups <- c(centroid_groups, cgrp)
    }
    m <- m |>
      leaflet::addCircleMarkers(data = geo_pts, radius = 0.1, stroke = FALSE, fillOpacity = 0,
        group = "geo-search", label = ~mm_label) |>
      leaflet::addLegend(position = "bottomright", colors = band_colors, labels = tlabels,
        title = if (is.null(g$time_legend)) "Drive time to<br>closest provider" else g$time_legend,
        className = paste0("info legend leg leg-", tok(tgrp))) |>
      leaflet::addLegend(position = "bottomright", pal = g$supply_pal, values = g$supply_values,
        title = if (is.null(g$supply_legend)) "Supply per capita" else g$supply_legend,
        na.label = "0 / no data",
        className = paste0("info legend leg leg-", tok(sgrp)))
    if (has_cov_g) {
      m <- m |> leaflet::addLegend(position = "bottomright", pal = g$coverage_pal, values = g$coverage_values,
        title = if (is.null(g$coverage_legend)) "Population coverage" else g$coverage_legend,
        labFormat = leaflet::labelFormat(suffix = "%"), na.label = "no data",
        className = paste0("info legend leg leg-", tok(cvgrp)))
    }
  }
  # Isochrone-reach overlay: nested band outlines of the area reachable within
  # the drive-time bands present in `iso_union$band` (widest/slowest outer, by
  # descending band, to narrowest/fastest inner). One group, one shape per
  # distinct band value present; hidden by default.
  iso_group <- character(0)
  if (!is.null(iso_union) && nrow(iso_union) > 0 && "band" %in% names(iso_union)) {
    iu <- iso_union[order(-iso_union$band), ]                 # worst (largest band) outer -> best inner
    band_values <- sort(unique(iso_union$band))
    iu$.col <- band_colors[match(iu$band, band_values)]
    iu$.lab <- sprintf("Reachable within %d min of a %s", iu$band, provider_noun)
    m <- m |> leaflet::addPolygons(data = iu, fill = FALSE, color = ~.col, weight = 1.6,
      opacity = 0.9, group = "Isochrone reach", label = ~.lab,
      highlightOptions = leaflet::highlightOptions(weight = 3, bringToFront = TRUE))
    iso_group <- "Isochrone reach"
  }
  m <- m |>
    leaflet::addCircleMarkers(data = providers, radius = 3, color = "#ffffff", weight = 1,
      stroke = TRUE, fillColor = provider_fill, fillOpacity = 0.9,
      group = "Providers", layerId = ~mm_id, label = ~mm_label, popup = ~mm_popup) |>
    leaflet::addControl(html = title_html, position = "topleft") |>
    leaflet::addControl(html = panel_html, position = "topright") |>
    leaflet::addControl(html = tools_html, position = "topleft") |>
    leaflet::addLayersControl(baseGroups = base_groups,
                              overlayGroups = c("Providers", "Dark basemap", iso_group, desert_groups, centroid_groups),
                              options = leaflet::layersControlOptions(collapsed = TRUE))
  for (h in desert_groups) m <- leaflet::hideGroup(m, h)
  for (h in centroid_groups) m <- leaflet::hideGroup(m, h)
  if (length(iso_group)) m <- leaflet::hideGroup(m, iso_group)
  m <- leaflet::hideGroup(m, "Dark basemap")
  m <- leaflet::fitBounds(m, conus_bounds[1], conus_bounds[2], conus_bounds[3], conus_bounds[4])
  m |>
    leaflet.extras::addSearchFeatures(targetGroups = c("geo-search", "Providers"),
      options = leaflet.extras::searchFeaturesOptions(zoom = 9, openPopup = TRUE, firstTipSubmit = TRUE,
        autoCollapse = TRUE, hideMarkerOnCollapse = TRUE, textPlaceholder = "Search a place or provider...")) |>
    htmlwidgets::onRender(combined_js, data = list(
      lookup = highlight_lookup, defGeo = geo_names[1], geoNames = as.list(geo_names),
      coverage = coverage_by_geo, conus = as.list(conus_bounds), worst = worst_by_geo,
      zips = zip_lookup, ariaLabel = aria_label))
}
