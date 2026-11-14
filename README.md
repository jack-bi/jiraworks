# Jira Works

個人使用的 Jira 牌卡整理工作台。前端部署於 GitHub Pages，牌卡、專案與留言資料儲存於 Supabase。

- 線上工作台：<https://jack-bi.github.io/jiraworks/>
- GitHub Repository：<https://github.com/jack-bi/jiraworks>

## 資料儲存方式

- `projects`、`tasks`、`comments`：儲存於 Supabase，可跨電腦同步。
- 圖片附件 metadata：儲存於 Supabase 的 `tasks.attachments`。
- 新上傳的圖片檔案：儲存於 Supabase Storage 的 `task-images` bucket，可跨電腦同步。
- 舊版圖片仍可從 GitHub Pages 的 `assets/images/` 或原瀏覽器 IndexedDB 讀取。
- `index.html` 內嵌的快照：只供資料庫空白時首次匯入，不是線上資料的主要來源。

> 目前 Supabase migration 的 RLS 規則允許匿名讀寫，僅適合個人測試資料。不要將公司或敏感資料放入這個專案。

## 本機預覽

在專案目錄執行：

```sh
python3 -m http.server 8000
```

開啟 <http://localhost:8000/>。圖片使用相對路徑載入，因此不能直接雙擊 `index.html` 預覽。

## 發布到 GitHub Pages

修改完成後提交並推送到 `main`：

```sh
git add .
git commit -m "描述這次修改"
git push origin main
```

GitHub Pages 會從這個 repository 發布網站。部署完成後開啟：

<https://jack-bi.github.io/jiraworks/>

若仍看到舊版本，可等待幾分鐘後強制重新整理：

- macOS：`Command + Shift + R`
- Windows：`Ctrl + Shift + R`

## 圖片與完整分享檔

`index.html` 的初始圖片已無損拆到 `assets/images/`。提交時必須同時包含 HTML 與整個 `assets/` 目錄。

「備份 JSON」與「匯出完整 HTML」會把圖片一併封裝。完整分享 HTML 可以單獨傳送與開啟，但檔案可能很大，不要直接拿它覆蓋 repository 裡的 `index.html`。

若需要把新的完整分享檔放回專案：

1. 先用完整分享檔取代 `index.html`。
2. 執行：

   ```sh
   python3 scripts/externalize-images.py index.html
   ```

3. 一併提交更新後的 `index.html` 與 `assets/images/`。

轉換腳本不會降低畫質，也不會自動刪除舊圖片。

## Supabase schema

資料庫結構位於：

```text
supabase/migrations/
```

需要在新的個人 Supabase Project 建立相同資料表與圖片 bucket 時，可先連結專案再套用 migration：

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_ID
supabase db push
```

前端只能使用 Supabase publishable key；不可把 secret key 或 service-role key 放進 `index.html`。
