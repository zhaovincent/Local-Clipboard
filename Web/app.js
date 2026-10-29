/* Local Clipboard — 界面逻辑 */
(function () {
  "use strict";

  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.prototype.slice.call((r || document).querySelectorAll(s));

  const state = {
    items: [],
    stats: null,
    settings: {},
    filter: "all",
    query: "",
    sel: 0,
    visible: [],
    recording: false,
    keepPinned: true
  };

  /* ---------------- 原生通信 ---------------- */
  function post(cmd, extra) {
    try {
      window.webkit.messageHandlers.clip.postMessage(Object.assign({ cmd: cmd }, extra || {}));
    } catch (e) { /* 非 WebView 环境 */ }
  }

  window.__native = {
    items(data) {
      state.items = Array.isArray(data) ? data : [];
      render();
      renderSettings();
    },
    stats(s) {
      state.stats = s;
      renderSettings();
      updateSubtitle();
    },
    settings(s) {
      state.settings = s || {};
      renderSettings();
      updateSubtitle();
    },
    open() {
      document.body.classList.add("open");
      closeSettings();
      hidePreview();
      state.query = "";
      $("#q").value = "";
      state.sel = 0;
      resetFilter();
      render();
      requestAnimationFrame(() => $("#q").focus());
      moveIndicator();
    },
    close() {
      document.body.classList.remove("open");
      closeSettings();
      hidePreview();
    },
    toast(t) {
      showToast(t && t.text ? t.text : String(t || ""));
    },
    preview(p) {
      if (!p) return;
      const item = state.items.find((i) => i.id === p.id);
      showPreview(p.src, item ? `${item.w} × ${item.h}` : "");
    },
    hotkeyRecording(r) {
      state.recording = false;
      const btn = $("#btnRecord");
      btn.classList.remove("recording");
      if (r && r.ok) {
        $("#recValue").textContent = r.display;
        showToast("快捷键已更新为 " + r.display);
      } else if (r && r.conflict) {
        showToast("该快捷键已被其他应用占用");
      }
      renderSettings();
    },
    openSettings() {
      openSettings();
    }
  };

  /* ---------------- 图标 ---------------- */
  const SVG = {
    text: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><path d="M5 7h14M5 12h10M5 17h7"/></svg>',
    link: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><path d="M10 13.5a3.6 3.6 0 0 0 5.1 0l2.6-2.6a3.6 3.6 0 0 0-5.1-5.1L11.4 7"/><path d="M14 10.5a3.6 3.6 0 0 0-5.1 0l-2.6 2.6a3.6 3.6 0 1 0 5.1 5.1L12.6 17"/></svg>',
    image: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="4.5" width="17" height="15" rx="3"/><circle cx="9" cy="10" r="1.5"/><path d="M4.5 17l4.6-4.4a2 2 0 0 1 2.7 0l3.1 2.9M14 15.2l1.6-1.5a2 2 0 0 1 2.7 0l1.7 1.6"/></svg>',
    file: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M13.5 3.5H7a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9z"/><path d="M13.5 3.5V9H19"/></svg>',
    pin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M9 4h6l-1 5 3 3v2H7v-2l3-3z"/><path d="M12 14v6"/></svg>',
    pinFill: '<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"><path d="M9 4h6l-1 5 3 3v2H7v-2l3-3z"/><path d="M12 14v6"/></svg>',
    copy: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="11" height="11" rx="2.5"/><path d="M15 6.5A2.5 2.5 0 0 0 12.5 4H6.5A2.5 2.5 0 0 0 4 6.5v6A2.5 2.5 0 0 0 6.5 15"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 7h15M9.5 7V5.2A1.2 1.2 0 0 1 10.7 4h2.6a1.2 1.2 0 0 1 1.2 1.2V7"/><path d="M6.5 7l.8 12A2 2 0 0 0 9.3 21h5.4a2 2 0 0 0 2-1.9L17.5 7"/><path d="M10.5 11v6M13.5 11v6"/></svg>',
    pinHead: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 4h6l-1 5 3 3v2H7v-2l3-3z"/></svg>'
  };

  const KIND_ICON = { text: SVG.text, link: SVG.link, image: SVG.image, file: SVG.file };
  const KIND_NAME = { text: "文本", link: "链接", image: "图片", file: "文件" };

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function timeAgo(ts) {
    const diff = Date.now() / 1000 - ts;
    if (diff < 45) return "刚刚";
    if (diff < 3600) return Math.floor(diff / 60) + " 分钟前";
    if (diff < 86400) return Math.floor(diff / 3600) + " 小时前";
    const d = new Date(ts * 1000);
    const hh = String(d.getHours()).padStart(2, "0");
    const mm = String(d.getMinutes()).padStart(2, "0");
    if (diff < 172800) return "昨天 " + hh + ":" + mm;
    return (d.getMonth() + 1) + "月" + d.getDate() + "日 " + hh + ":" + mm;
  }

  function sizeText(n) {
    if (!n) return "";
    if (n < 1024) return n + " B";
    if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB";
    return (n / 1024 / 1024).toFixed(1) + " MB";
  }

  /* ---------------- 渲染 ---------------- */
  function visibleItems() {
    const q = state.query.trim().toLowerCase();
    let list = state.items.filter((it) => {
      if (state.filter === "pin") return it.pinned;
      if (state.filter === "text") return it.kind === "text" || it.kind === "link";
      if (state.filter === "image") return it.kind === "image";
      if (state.filter === "file") return it.kind === "file";
      return true;
    });
    if (q) {
      list = list.filter((it) => {
        const t = (it.text || "").toLowerCase();
        const s = (it.source || "").toLowerCase();
        return t.indexOf(q) >= 0 || s.indexOf(q) >= 0;
      });
    }
    return list;
  }

  function metaHTML(it) {
    const parts = [];
    if (it.source) parts.push('<span class="src">' + esc(it.source) + "</span>");
    parts.push("<span>" + timeAgo(it.createdAt) + "</span>");
    if (it.kind === "image") {
      parts.push("<span>" + (it.w || 0) + " × " + (it.h || 0) + "</span>");
      parts.push("<span>" + sizeText(it.size) + "</span>");
    } else if (it.kind === "file") {
      const n = (it.text || "").split("\n").filter(Boolean).length;
      parts.push("<span>" + n + " 个文件</span>");
    } else if (it.kind === "link") {
      parts.push("<span>链接</span>");
    } else {
      parts.push("<span>" + (it.len || 0) + " 字</span>");
    }
    let html = "";
    parts.forEach((p, i) => {
      if (i) html += '<span class="sep"></span>';
      html += p;
    });
    return html;
  }

  function cardHTML(it, index) {
    const isImage = it.kind === "image" && it.thumb;
    const lead = isImage
      ? '<img class="thumb" data-act="preview" data-id="' + it.id + '" src="' + it.thumb + '" alt="" />'
      : '<div class="tile">' + (KIND_ICON[it.kind] || SVG.text) + "</div>";
    let text = it.text || "";
    if (it.kind === "image") text = "图片 " + (it.w || 0) + " × " + (it.h || 0);
    if (it.kind === "file") {
      text = text.split("\n").filter(Boolean).map((p) => p.split("/").pop()).join("、");
    }
    const mono = it.kind === "link" ? " mono" : "";
    return (
      '<div class="card k-' + it.kind + '" data-id="' + it.id + '" data-i="' + index + '" style="--i:' + Math.min(index, 16) + '">' +
      lead +
      '<div class="body">' +
      '<div class="txt' + mono + '">' + esc(text) + "</div>" +
      '<div class="meta">' + metaHTML(it) + "</div>" +
      "</div>" +
      '<div class="acts">' +
      '<button data-act="pin" data-id="' + it.id + '" class="' + (it.pinned ? "on" : "") + '" data-tip="' + (it.pinned ? "取消置顶" : "置顶") + '">' + (it.pinned ? SVG.pinFill : SVG.pin) + "</button>" +
      '<button data-act="copy" data-id="' + it.id + '" data-tip="复制并粘贴 ↵">' + SVG.copy + "</button>" +
      '<button data-act="del" data-id="' + it.id + '" data-tip="删除 ⌘⌫">' + SVG.trash + "</button>" +
      "</div>" +
      '<div class="flash"></div>' +
      "</div>"
    );
  }

  function render() {
    const list = visibleItems();
    state.visible = list;
    const wrap = $("#list");

    if (state.sel >= list.length) state.sel = Math.max(0, list.length - 1);

    if (!list.length) {
      wrap.innerHTML = "";
      const empty = $("#empty");
      empty.classList.add("show");
      if (state.query) {
        $("#emptyTitle").textContent = "没有找到匹配的记录";
        $("#emptyDesc").textContent = "试试其他关键词，或按 esc 清空搜索";
      } else if (state.filter !== "all") {
        $("#emptyTitle").textContent = "这个分类还没有内容";
        $("#emptyDesc").textContent = "复制对应类型的内容后会自动出现在这里";
      } else {
        $("#emptyTitle").textContent = "还没有剪贴板记录";
        $("#emptyDesc").textContent = "复制任意文字、图片或文件，这里会自动收集";
      }
      return;
    }
    $("#empty").classList.remove("show");

    let html = "";
    let pinnedHead = false;
    let normalHead = false;
    list.forEach((it, i) => {
      if (state.filter !== "pin") {
        if (it.pinned && !pinnedHead) {
          html += '<div class="sechead">' + SVG.pinHead + "置顶</div>";
          pinnedHead = true;
        }
        if (!it.pinned && !normalHead) {
          html += '<div class="sechead">最近</div>';
          normalHead = true;
        }
      }
      html += cardHTML(it, i);
    });
    wrap.innerHTML = html;
    applySelection(false);
  }

  function applySelection(scroll) {
    $$(".card", $("#list")).forEach((c) => {
      const on = Number(c.dataset.i) === state.sel;
      c.classList.toggle("sel", on);
      if (on && scroll) c.scrollIntoView({ block: "nearest" });
    });
  }

  function updateSubtitle() {
    const s = state.stats || { count: 0 };
    let text = "剪贴板历史 · " + s.count + " 条";
    if (s.pinned) text += " · " + s.pinned + " 置顶";
    $("#subtitle").textContent = text;
  }

  /* ---------------- 操作 ---------------- */
  function copyItem(id) {
    const card = $('.card[data-id="' + id + '"]');
    if (card) {
      card.classList.remove("flash-on");
      void card.offsetWidth;
      card.classList.add("flash-on");
    }
    post("copy", { id: id });
  }

  function selectedId() {
    const it = state.visible[state.sel];
    return it ? it.id : null;
  }

  /* ---------------- 设置 ---------------- */
  function renderSettings() {
    const s = state.settings || {};

    $$(".switch[data-key]").forEach((b) => {
      b.classList.toggle("on", !!s[b.dataset.key]);
    });

    const rec = $("#recValue");
    if (rec && s.hotkey) rec.textContent = s.hotkey;
    const ek = $("#emptyKey");
    if (ek && s.hotkey) ek.textContent = s.hotkey;

    $$(".pills").forEach((p) => {
      const v = String(s[p.dataset.key] == null ? "" : s[p.dataset.key]);
      $$("button", p).forEach((btn) => btn.classList.toggle("on", btn.dataset.v === v));
    });

    const st = state.stats;
    $("#usageDesc").textContent = st
      ? st.bytesText + " · " + st.count + " 条记录 · " + st.images + " 张图片"
      : "—";
    $("#verLabel").textContent = s.version || "";

    $("#btnAutoPaste").classList.toggle("on", !!s.autoPaste);
    $("#apText").textContent = s.autoPaste ? "自动粘贴" : "仅复制";
    $("#keepPinnedSw").classList.toggle("on", state.keepPinned);

    const hd = $("#hotkeyDesc");
    if (hd) {
      if (s.hotkeyOk === false) {
        hd.textContent = "当前快捷键被占用或注册失败，请点击右侧重新设置";
        hd.style.color = "#ffb26b";
      } else {
        hd.textContent = "在任意应用中呼出剪贴板历史";
        hd.style.color = "";
      }
    }

    const ax = $("#axDesc");
    if (ax && s.trusted === false) {
      ax.textContent = "未获得「辅助功能」授权，复制后不会自动粘贴（点击此处前往授权）";
      ax.style.color = "#ffb26b";
      ax.style.cursor = "pointer";
      ax.onclick = () => post("openAX");
    }
  }

  function resetFilter() {
    state.filter = "all";
    $$(".tab").forEach((t) => t.classList.toggle("on", t.dataset.f === "all"));
    moveIndicator();
  }

  function openSettings() {
    $("#settings").classList.add("open");
    post("getSettings");
  }
  function closeSettings() {
    $("#settings").classList.remove("open");
  }

  function showToast(text) {
    if (!text) return;
    const t = $("#toast");
    $("#toastText").textContent = text;
    t.classList.add("show");
    clearTimeout(showToast._timer);
    showToast._timer = setTimeout(() => t.classList.remove("show"), 1900);
  }

  function showPreview(src, meta) {
    if (!src) return;
    $("#previewImg").src = src;
    $("#previewMeta").textContent = meta || "";
    $("#preview").classList.add("open");
  }
  function hidePreview() {
    $("#preview").classList.remove("open");
    $("#previewImg").removeAttribute("src");
  }

  /* ---------------- 标签指示器 ---------------- */
  function moveIndicator() {
    const active = $(".tab.on");
    const ind = $("#tabind");
    if (!active || !ind) return;
    ind.style.width = active.offsetWidth + "px";
    ind.style.transform = "translateX(" + (active.offsetLeft - 3) + "px)";
  }

  /* ---------------- 事件 ---------------- */
  function bind() {
    // 顶栏
    $("#btnSettings").addEventListener("click", openSettings);
    $("#btnClose").addEventListener("click", () => post("hide"));
    $("#btnBack").addEventListener("click", closeSettings);

    // 搜索
    const q = $("#q");
    q.addEventListener("input", () => {
      state.query = q.value;
      state.sel = 0;
      render();
    });
    q.addEventListener("focus", () => $("#searchWrap").classList.add("focus"));
    q.addEventListener("blur", () => $("#searchWrap").classList.remove("focus"));

    // 标签
    $$(".tab").forEach((tab) => {
      tab.addEventListener("click", () => {
        $$(".tab").forEach((t) => t.classList.remove("on"));
        tab.classList.add("on");
        state.filter = tab.dataset.f;
        state.sel = 0;
        moveIndicator();
        render();
      });
    });

    // 列表委托
    $("#list").addEventListener("click", (e) => {
      const actEl = e.target.closest("[data-act]");
      if (actEl) {
        e.stopPropagation();
        const act = actEl.dataset.act;
        const id = actEl.dataset.id || (actEl.closest(".card") || {}).dataset?.id;
        if (!id) return;
        if (act === "copy") copyItem(id);
        else if (act === "pin") post("pin", { id: id });
        else if (act === "del") post("delete", { id: id });
        else if (act === "preview") post("preview", { id: id });
        return;
      }
      const card = e.target.closest(".card");
      if (card) copyItem(card.dataset.id);
    });

    $("#list").addEventListener("mousemove", (e) => {
      const card = e.target.closest(".card");
      if (!card) return;
      const i = Number(card.dataset.i);
      if (i !== state.sel) {
        state.sel = i;
        applySelection(false);
      }
    });

    // 底栏
    $("#btnAutoPaste").addEventListener("click", () => {
      const next = !state.settings.autoPaste;
      state.settings.autoPaste = next;
      renderSettings();
      post("applySettings", { values: { autoPaste: next } });
    });

    // 设置项
    $$(".switch[data-key]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const key = btn.dataset.key;
        const next = !btn.classList.contains("on");
        btn.classList.toggle("on", next);
        state.settings[key] = next;
        post("applySettings", { values: { [key]: next } });
      });
    });

    $$(".pills").forEach((p) => {
      p.addEventListener("click", (e) => {
        const btn = e.target.closest("button");
        if (!btn) return;
        $$("button", p).forEach((b) => b.classList.remove("on"));
        btn.classList.add("on");
        const key = p.dataset.key;
        const val = parseInt(btn.dataset.v, 10);
        state.settings[key] = val;
        post("applySettings", { values: { [key]: val } });
      });
    });

    $("#keepPinnedSw").addEventListener("click", () => {
      state.keepPinned = !state.keepPinned;
      renderSettings();
    });

    $("#btnClear").addEventListener("click", () => {
      post("clearAll", { keepPinned: state.keepPinned });
    });
    $("#btnReveal").addEventListener("click", () => post("revealData"));
    $("#btnQuit").addEventListener("click", () => post("quit"));

    // 快捷键录制
    $("#btnRecord").addEventListener("click", () => {
      if (state.recording) {
        state.recording = false;
        $("#btnRecord").classList.remove("recording");
        $("#recValue").textContent = state.settings.hotkey || "⌘⇧V";
        post("cancelRecord");
        return;
      }
      state.recording = true;
      $("#btnRecord").classList.add("recording");
      $("#recValue").textContent = "按下按键…";
      post("recordHotkey");
    });

    // 预览
    $("#preview").addEventListener("click", hidePreview);
    $("#btnPreviewClose").addEventListener("click", (e) => {
      e.stopPropagation();
      hidePreview();
    });

    // 键盘
    document.addEventListener("keydown", (e) => {
      if (state.recording) return;
      const meta = e.metaKey;
      const key = e.key;

      if (key === "Escape") {
        e.preventDefault();
        if ($("#preview").classList.contains("open")) { hidePreview(); return; }
        if ($("#settings").classList.contains("open")) { closeSettings(); return; }
        if (state.query) {
          state.query = "";
          $("#q").value = "";
          render();
          return;
        }
        post("hide");
        return;
      }

      if (meta && (key === "f" || key === "F")) {
        e.preventDefault();
        $("#q").focus();
        $("#q").select();
        return;
      }

      if (meta && key === ",") {
        e.preventDefault();
        openSettings();
        return;
      }

      if ($("#settings").classList.contains("open")) return;

      if (key === "ArrowDown") {
        e.preventDefault();
        if (!state.visible.length) return;
        state.sel = Math.min(state.visible.length - 1, state.sel + 1);
        applySelection(true);
        return;
      }
      if (key === "ArrowUp") {
        e.preventDefault();
        if (!state.visible.length) return;
        state.sel = Math.max(0, state.sel - 1);
        applySelection(true);
        return;
      }
      if (key === "Enter") {
        e.preventDefault();
        const id = selectedId();
        if (id) copyItem(id);
        return;
      }
      if (meta && key === "Backspace") {
        e.preventDefault();
        const id = selectedId();
        if (id) post("delete", { id: id });
        return;
      }
      if (meta && /^[1-9]$/.test(key)) {
        e.preventDefault();
        const idx = parseInt(key, 10) - 1;
        const it = state.visible[idx];
        if (it) copyItem(it.id);
        return;
      }
    });

    // 悬浮提示
    const tip = document.createElement("div");
    tip.className = "tipbox";
    document.body.appendChild(tip);
    document.addEventListener("mouseover", (e) => {
      const el = e.target.closest("[data-tip]");
      if (!el) { tip.classList.remove("show"); return; }
      tip.textContent = el.dataset.tip;
      tip.classList.add("show");
      const r = el.getBoundingClientRect();
      const tw = tip.offsetWidth;
      let left = r.left + r.width / 2 - tw / 2;
      left = Math.max(6, Math.min(left, window.innerWidth - tw - 6));
      tip.style.left = left + "px";
      tip.style.top = Math.max(4, r.top - 24) + "px";
    });
    document.addEventListener("mouseout", (e) => {
      if (!e.relatedTarget || !e.relatedTarget.closest || !e.relatedTarget.closest("[data-tip]")) {
        tip.classList.remove("show");
      }
    });

    window.addEventListener("resize", moveIndicator);
    document.addEventListener("contextmenu", (e) => e.preventDefault());
  }

  bind();
  requestAnimationFrame(moveIndicator);

  // 首屏骨架（等待 Swift 推送数据）
  updateSubtitle();
  moveIndicator();

  // 关键：告诉原生端脚本已就绪，Swift 收到 ready 后才会推送历史与设置
  post("ready");
  // 兜底：若 ready 在原生端监听注册前发出（极端竞态），再补发一次
  setTimeout(() => post("ready"), 300);
})();
