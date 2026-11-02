/*
 * Copyright 2026 junyue
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* Local Clipboard — 界面逻辑 / UI logic */
(function () {
  "use strict";

  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.prototype.slice.call((r || document).querySelectorAll(s));

  /* ---------------- 国际化 / i18n ---------------- */
  const I18N = {
    zh: {
      brandSub: "剪贴板历史",
      tabAll: "全部",
      tabText: "文本",
      tabImage: "图片",
      tabFile: "文件",
      tabPin: "置顶",
      sectionPinned: "置顶",
      sectionRecent: "最近",
      hintSelect: " 选择",
      hintCopy: " 复制",
      hintDelete: " 删除",
      autoPaste: "自动粘贴",
      copyOnly: "仅复制",
      emptyTitle: "还没有剪贴板记录",
      emptyDesc: "复制任意文字、图片或文件，这里会自动收集",
      emptyKeySuffix: "随时唤出面板",
      emptyNoMatch: "没有找到匹配的记录",
      emptyNoMatchDesc: "试试其他关键词，或按 esc 清空搜索",
      emptyFilter: "这个分类还没有内容",
      emptyFilterDesc: "复制对应类型的内容后会自动出现在这里",
      settingsTitle: "设置",
      searchPh: "搜索剪贴板历史…",
      grpGeneral: "通用",
      language: "语言 / Language",
      languageDesc: "界面显示语言，跟随系统可自动选择",
      followSystem: "跟随系统",
      chinese: "中文",
      english: "English",
      appearance: "外观",
      appearanceDesc: "深浅色模式，可跟随系统自动切换",
      light: "浅色",
      dark: "深色",
      launchLogin: "开机自动启动",
      launchLoginDesc: "登录后自动在后台运行",
      autoPasteRow: "复制后自动粘贴",
      autoPasteDesc: "选中记录后直接粘贴到当前应用（需辅助功能授权）",
      plainText: "仅粘贴纯文本",
      plainTextDesc: "去除富文本样式与链接格式",
      playSound: "复制提示音",
      playSoundDesc: "复制成功时播放轻提示音",
      grpHotkey: "快捷键",
      hotkeyGlobal: "全局唤出面板",
      hotkeyGlobalDesc: "在任意应用中呼出剪贴板历史",
      hotkeyBusyDesc: "当前快捷键被占用或注册失败，请点击右侧重新设置",
      inPanelKeys: "面板内快捷操作",
      inPanelKeysDesc: "↑↓ 选择 · ↵ 复制 · ⌘1–9 快速复制 · ⌘⌫ 删除",
      grpHistory: "历史存储",
      keepItems: "保留条数",
      imgLimit: "图片存储上限",
      autoClean: "自动清理",
      never: "永不",
      d7: "7 天",
      d30: "30 天",
      d90: "90 天",
      grpStorage: "存储",
      storageDir: "存储位置",
      storageDefault: "默认（~/Library/Application Support/Local Clipboard）",
      change: "更改…",
      reset: "恢复默认",
      backup: "备份与恢复",
      backupDesc: "导出全部历史为 zip，或在其他电脑导入合并",
      exportBtn: "导出…",
      importBtn: "导入…",
      usage: "已用空间",
      reveal: "打开目录",
      clearBtn: "清空",
      clearMode: "清空方式",
      clearModeDesc: "清空时保留已置顶的记录",
      aboutDesc: "原生剪贴板历史 · 本地存储 · 不上传任何数据",
      quit: "退出 Local Clipboard",
      previewClose: "关闭",
      tipSettings: "设置 ⌘,",
      tipClose: "关闭 esc",
      tipAutopaste: "复制后自动粘贴到当前应用",
      tipBack: "返回",
      tipClearHead: "清空历史（保留置顶）",
      tipClearAll: "清空全部历史",
      tipPin: "置顶",
      tipUnpin: "取消置顶",
      tipCopy: "复制并粘贴 ↵",
      tipDelete: "删除 ⌘⌫",
      usageLine: "{0} · {1} · {2}",
      itemCount: "{0} 条记录",
      imageCount: "{0} 张图片",
      subtitleBase: "剪贴板历史 · {0} 条",
      subtitlePinned: " · {0} 置顶",
      timeJustNow: "刚刚",
      timeMinutes: "{0} 分钟前",
      timeHours: "{0} 小时前",
      timeYesterday: "昨天 {0}",
      timeDate: "{0}月{1}日 {2}",
      metaFiles: "{0} 个文件",
      metaLink: "链接",
      metaChars: "{0} 字",
      imageLabel: "图片 {0} × {1}",
      kindText: "文本",
      kindLink: "链接",
      kindImage: "图片",
      kindFile: "文件",
      recWaiting: "按下按键…",
      toastHotkeyUpdated: "快捷键已更新为 {0}",
      toastHotkeyConflict: "该快捷键已被其他应用占用",
      toastClearConfirmAll: "再次点击清空全部历史",
      toastClearConfirmKeep: "再次点击清空历史（保留置顶）",
      axWarn: "未获得「辅助功能」授权，复制后不会自动粘贴（点击此处前往授权）"
    },
    en: {
      brandSub: "Clipboard History",
      tabAll: "All",
      tabText: "Text",
      tabImage: "Images",
      tabFile: "Files",
      tabPin: "Pinned",
      sectionPinned: "Pinned",
      sectionRecent: "Recent",
      hintSelect: " Select",
      hintCopy: " Copy",
      hintDelete: " Delete",
      autoPaste: "Auto-paste",
      copyOnly: "Copy only",
      emptyTitle: "No clipboard history yet",
      emptyDesc: "Copy any text, image or file and it will be collected here",
      emptyKeySuffix: "opens the panel anytime",
      emptyNoMatch: "No matching items",
      emptyNoMatchDesc: "Try another keyword, or press esc to clear the search",
      emptyFilter: "Nothing in this category yet",
      emptyFilterDesc: "Copy something of this type and it will show up here",
      settingsTitle: "Settings",
      searchPh: "Search clipboard history…",
      grpGeneral: "General",
      language: "Language",
      languageDesc: "Interface language. Auto follows your Mac.",
      followSystem: "Auto",
      chinese: "中文",
      english: "English",
      appearance: "Appearance",
      appearanceDesc: "Light or dark theme, or follow the system",
      light: "Light",
      dark: "Dark",
      launchLogin: "Launch at login",
      launchLoginDesc: "Run in the background after you log in",
      autoPasteRow: "Paste after copying",
      autoPasteDesc: "Paste into the current app right after you pick an item (needs Accessibility)",
      plainText: "Paste as plain text",
      plainTextDesc: "Strip rich text styling and link formatting",
      playSound: "Sound on copy",
      playSoundDesc: "Play a soft sound when an item is copied",
      grpHotkey: "Shortcut",
      hotkeyGlobal: "Global shortcut",
      hotkeyGlobalDesc: "Open clipboard history from any app",
      hotkeyBusyDesc: "This shortcut is taken or failed to register — set a new one on the right",
      inPanelKeys: "In-panel shortcuts",
      inPanelKeysDesc: "↑↓ select · ↵ copy · ⌘1–9 quick copy · ⌘⌫ delete",
      grpHistory: "History",
      keepItems: "Items to keep",
      imgLimit: "Image storage limit",
      autoClean: "Auto cleanup",
      never: "Never",
      d7: "7 days",
      d30: "30 days",
      d90: "90 days",
      grpStorage: "Storage",
      storageDir: "Storage location",
      storageDefault: "Default (~/Library/Application Support/Local Clipboard)",
      change: "Change…",
      reset: "Reset to default",
      backup: "Backup & restore",
      backupDesc: "Export all history as a zip, or import and merge it on another Mac",
      exportBtn: "Export…",
      importBtn: "Import…",
      usage: "Space used",
      reveal: "Show folder",
      clearBtn: "Clear",
      clearMode: "Clear behavior",
      clearModeDesc: "Keep pinned items when clearing",
      aboutDesc: "Native clipboard history · Stored locally · Nothing leaves your Mac",
      quit: "Quit Local Clipboard",
      previewClose: "Close",
      tipSettings: "Settings ⌘,",
      tipClose: "Close esc",
      tipAutopaste: "Paste into the current app after copying",
      tipBack: "Back",
      tipClearHead: "Clear history (keep pinned)",
      tipClearAll: "Clear all history",
      tipPin: "Pin",
      tipUnpin: "Unpin",
      tipCopy: "Copy and paste ↵",
      tipDelete: "Delete ⌘⌫",
      usageLine: "{0} · {1} · {2}",
      itemCount: "{0} items",
      itemCountOne: "{0} item",
      imageCount: "{0} images",
      imageCountOne: "{0} image",
      subtitleBase: "Clipboard History · {0} items",
      subtitleBaseOne: "Clipboard History · {0} item",
      subtitlePinned: " · {0} pinned",
      timeJustNow: "Just now",
      timeMinutes: "{0} min ago",
      timeHours: "{0} h ago",
      timeYesterday: "Yesterday {0}",
      timeDate: "{0}/{1} {2}",
      metaFiles: "{0} files",
      metaLink: "Link",
      metaChars: "{0} chars",
      imageLabel: "Image {0} × {1}",
      kindText: "Text",
      kindLink: "Link",
      kindImage: "Image",
      kindFile: "File",
      recWaiting: "Press keys…",
      toastHotkeyUpdated: "Shortcut updated to {0}",
      toastHotkeyConflict: "That shortcut is already taken by another app",
      toastClearConfirmAll: "Click again to clear all history",
      toastClearConfirmKeep: "Click again to clear history (pinned kept)",
      axWarn: "Accessibility permission is not granted, so items will be copied but not pasted (click to grant)"
    }
  };

  let LANG = "zh";

  function t(key) {
    const args = Array.prototype.slice.call(arguments, 1);
    const table = I18N[LANG] || I18N.zh;
    let s = table[key];
    if (s == null) s = I18N.zh[key];
    if (s == null) return key;
    if (args.length) {
      s = s.replace(/\{(\d+)\}/g, (m, i) => (args[Number(i)] != null ? String(args[Number(i)]) : m));
    }
    return s;
  }

  /* ---------------- 原生通信 ---------------- */
  function post(cmd, extra) {
    try {
      window.webkit.messageHandlers.clip.postMessage(Object.assign({ cmd: cmd }, extra || {}));
    } catch (e) { /* 非 WebView 环境 */ }
  }

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
      // 语言：原生侧解析 auto 后下发生效语言，切语言时整页重刷文案
      if (s && s.lang && s.lang !== LANG) setLang(s.lang);
      // 首次拿到设置时先按 dark 标志上底色，避免等原生 theme() 期间闪白
      if (document.documentElement.dataset.theme === undefined && s && typeof s.dark === "boolean") {
        document.documentElement.dataset.theme = s.dark ? "dark" : "light";
      }
      renderSettings();
      updateSubtitle();
    },
    open() {
      document.body.classList.add("open");
      closeSettings();
      hidePreview();
      disarmedClear();
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
      disarmedClear();
    },
    toast(t0) {
      showToast(t0 && t0.text ? t0.text : String(t0 || ""));
    },
    theme(th) {
      if (th && th.mode) state.settings.appearance = th.mode;
      // dark 由原生侧解析（auto 时跟随系统），网页只认最终结果
      document.documentElement.dataset.theme = th && th.dark ? "dark" : "light";
      renderSettings();
    },
    preview(p) {
      if (!p) return;
      const item = state.items.find((i) => i.id === p.id);
      showPreview(p.src, item ? t("imageLabel", item.w || 0, item.h || 0) : "");
    },
    hotkeyRecording(r) {
      state.recording = false;
      const btn = $("#btnRecord");
      btn.classList.remove("recording");
      if (r && r.ok) {
        $("#recValue").textContent = r.display;
        showToast(t("toastHotkeyUpdated", r.display));
      } else if (r && r.conflict) {
        showToast(t("toastHotkeyConflict"));
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

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  /// 计数文案：英文单数取 xxxOne 变体，中文始终用基数
  function countOf(n, baseKey) {
    const oneKey = baseKey + "One";
    const key = LANG === "en" && n === 1 && I18N.en[oneKey] ? oneKey : baseKey;
    return t(key, n);
  }

  function timeAgo(ts) {
    const diff = Date.now() / 1000 - ts;
    if (diff < 45) return t("timeJustNow");
    if (diff < 3600) return t("timeMinutes", Math.floor(diff / 60));
    if (diff < 86400) return t("timeHours", Math.floor(diff / 3600));
    const d = new Date(ts * 1000);
    const hh = String(d.getHours()).padStart(2, "0");
    const mm = String(d.getMinutes()).padStart(2, "0");
    if (diff < 172800) return t("timeYesterday", hh + ":" + mm);
    return t("timeDate", d.getMonth() + 1, d.getDate(), hh + ":" + mm);
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
        const tx = (it.text || "").toLowerCase();
        const sr = (it.source || "").toLowerCase();
        return tx.indexOf(q) >= 0 || sr.indexOf(q) >= 0;
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
      parts.push("<span>" + t("metaFiles", n) + "</span>");
    } else if (it.kind === "link") {
      parts.push("<span>" + t("metaLink") + "</span>");
    } else {
      parts.push("<span>" + t("metaChars", it.len || 0) + "</span>");
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
    if (it.kind === "image") text = t("imageLabel", it.w || 0, it.h || 0);
    if (it.kind === "file") {
      text = text.split("\n").filter(Boolean).map((p) => p.split("/").pop()).join(LANG === "en" ? ", " : "、");
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
      '<button data-act="pin" data-id="' + it.id + '" class="' + (it.pinned ? "on" : "") + '" data-tip="' + esc(it.pinned ? t("tipUnpin") : t("tipPin")) + '">' + (it.pinned ? SVG.pinFill : SVG.pin) + "</button>" +
      '<button data-act="copy" data-id="' + it.id + '" data-tip="' + esc(t("tipCopy")) + '">' + SVG.copy + "</button>" +
      '<button data-act="del" data-id="' + it.id + '" data-tip="' + esc(t("tipDelete")) + '">' + SVG.trash + "</button>" +
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
        $("#emptyTitle").textContent = t("emptyNoMatch");
        $("#emptyDesc").textContent = t("emptyNoMatchDesc");
      } else if (state.filter !== "all") {
        $("#emptyTitle").textContent = t("emptyFilter");
        $("#emptyDesc").textContent = t("emptyFilterDesc");
      } else {
        $("#emptyTitle").textContent = t("emptyTitle");
        $("#emptyDesc").textContent = t("emptyDesc");
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
          html += '<div class="sechead">' + SVG.pinHead + esc(t("sectionPinned")) + "</div>";
          pinnedHead = true;
        }
        if (!it.pinned && !normalHead) {
          html += '<div class="sechead">' + esc(t("sectionRecent")) + "</div>";
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
    let text = countOf(s.count || 0, "subtitleBase");
    if (s.pinned) text += t("subtitlePinned", s.pinned);
    $("#subtitle").textContent = text;
  }

  /* ---------------- 视图层文案切换 ---------------- */
  function applyI18n() {
    $$("[data-i18n]").forEach((el) => { el.textContent = t(el.dataset.i18n); });
    $$("[data-i18n-tip]").forEach((el) => { el.dataset.tip = t(el.dataset.i18nTip); });
    $$("[data-i18n-ph]").forEach((el) => { el.placeholder = t(el.dataset.i18nPh); });
    syncClearTips();
    updateSubtitle();
    const ap = $("#apText");
    if (ap) ap.textContent = state.settings.autoPaste ? t("autoPaste") : t("copyOnly");
    if (state.recording) $("#recValue").textContent = t("recWaiting");
  }

  function setLang(lang) {
    LANG = lang === "en" ? "en" : "zh";
    document.documentElement.lang = LANG === "en" ? "en" : "zh-Hans";
    applyI18n();
    render();
    renderSettings();
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
    if (rec && s.hotkey && !state.recording) rec.textContent = s.hotkey;
    const ek = $("#emptyKey");
    if (ek && s.hotkey) ek.textContent = s.hotkey;

    $$(".pills").forEach((p) => {
      const v = String(s[p.dataset.key] == null ? "" : s[p.dataset.key]);
      $$("button", p).forEach((btn) => btn.classList.toggle("on", btn.dataset.v === v));
    });

    const st = state.stats;
    $("#usageDesc").textContent = st
      ? t("usageLine", st.bytesText, countOf(st.count, "itemCount"), countOf(st.images, "imageCount"))
      : "—";
    $("#verLabel").textContent = s.version || "";

    const sd = $("#storageDirLabel");
    if (sd) {
      const dir = s.storageDir || "";
      if (s.storageIsCustom) {
        sd.textContent = dir;
        sd.title = dir;
      } else {
        sd.textContent = t("storageDefault");
        sd.title = dir;
      }
    }
    const br = $("#btnResetDir");
    if (br) {
      const on = !!s.storageIsCustom;
      br.style.opacity = on ? "" : "0.4";
      br.style.pointerEvents = on ? "" : "none";
    }

    $("#btnAutoPaste").classList.toggle("on", !!s.autoPaste);
    $("#apText").textContent = s.autoPaste ? t("autoPaste") : t("copyOnly");
    $("#keepPinnedSw").classList.toggle("on", state.keepPinned);
    syncClearTips();

    const hd = $("#hotkeyDesc");
    if (hd) {
      if (s.hotkeyOk === false) {
        hd.textContent = t("hotkeyBusyDesc");
        hd.style.color = "#ffb26b";
      } else {
        hd.textContent = t("hotkeyGlobalDesc");
        hd.style.color = "";
      }
    }

    const ax = $("#axDesc");
    if (ax && s.trusted === false) {
      ax.textContent = t("axWarn");
      ax.style.color = "#ffb26b";
      ax.style.cursor = "pointer";
      ax.onclick = () => post("openAX");
    } else if (ax) {
      ax.textContent = t("autoPasteDesc");
      ax.style.color = "";
      ax.style.cursor = "";
      ax.onclick = null;
    }
  }

  function resetFilter() {
    state.filter = "all";
    $$(".tab").forEach((tb) => tb.classList.toggle("on", tb.dataset.f === "all"));
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
    const tip = $("#toast");
    $("#toastText").textContent = text;
    tip.classList.add("show");
    clearTimeout(showToast._timer);
    showToast._timer = setTimeout(() => tip.classList.remove("show"), 1900);
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

  /* ---------------- 一键清除（二次确认） ---------------- */
  const clearArm = { who: null, at: 0, timer: 0 };

  function syncClearTips() {
    const head = $("#btnClearHead");
    if (head && clearArm.who !== "head") {
      head.dataset.tip = state.keepPinned ? t("tipClearHead") : t("tipClearAll");
    }
  }

  function disarmedClear() {
    clearArm.who = null;
    clearArm.at = 0;
    clearTimeout(clearArm.timer);
    $$(".arming").forEach((el) => el.classList.remove("arming"));
    syncClearTips();
  }

  /// 第一次点击进入待确认态（3.5s 内），第二次点击才真正清空
  function requestClear(who, btn) {
    const keep = state.keepPinned;
    const now = Date.now();
    if (clearArm.who === who && now - clearArm.at < 3500) {
      disarmedClear();
      post("clearAll", { keepPinned: keep });
      return;
    }
    clearArm.who = who;
    clearArm.at = now;
    if (btn) btn.classList.add("arming");
    clearTimeout(clearArm.timer);
    clearArm.timer = setTimeout(() => disarmedClear(), 3500);
    showToast(keep ? t("toastClearConfirmKeep") : t("toastClearConfirmAll"));
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

    const clearHead = $("#btnClearHead");
    if (clearHead) clearHead.addEventListener("click", () => requestClear("head", clearHead));

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
        $$(".tab").forEach((tb) => tb.classList.remove("on"));
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
        const raw = btn.dataset.v;
        const val = p.dataset.type === "str" ? raw : parseInt(raw, 10);
        state.settings[key] = val;
        post("applySettings", { values: { [key]: val } });
      });
    });

    $("#keepPinnedSw").addEventListener("click", () => {
      state.keepPinned = !state.keepPinned;
      renderSettings();
      applyI18n();
    });

    const btnClear = $("#btnClear");
    if (btnClear) btnClear.addEventListener("click", () => requestClear("settings", btnClear));
    $("#btnReveal").addEventListener("click", () => post("revealData"));
    $("#btnQuit").addEventListener("click", () => post("quit"));
    $("#btnChangeDir").addEventListener("click", () => post("chooseStorageDir"));
    $("#btnResetDir").addEventListener("click", () => post("resetStorageDir"));
    $("#btnExport").addEventListener("click", () => post("exportData"));
    $("#btnImport").addEventListener("click", () => post("importData"));

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
      $("#recValue").textContent = t("recWaiting");
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
        if (clearArm.who) { disarmedClear(); return; }
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

  // 首屏语言：先按系统语言猜测，原生推来 lang 后再校正
  setLang(/^zh/i.test(navigator.language || "") ? "zh" : "en");

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
