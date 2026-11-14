#!/usr/bin/env python3
"""將完整分享 HTML 的內嵌圖片無損拆出，供 Git 與靜態網站使用。"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('html', nargs='?', default='index.html')
    args = parser.parse_args()
    path = Path(args.html)
    source = path.read_text(encoding='utf-8')
    match = re.search(
        r'(<script id="fbcom-share-snapshot" type="application/json">)(.*?)(</script>)',
        source, re.S,
    )
    if not match:
        raise ValueError('找不到分享快照')
    snapshot = json.loads(match[2])
    images = snapshot.get('imageBlobs', {})
    if not images:
        print('沒有需要拆出的內嵌圖片。')
        return
    if 'const SHARED_IMAGE_FILES=' not in source:
        raise ValueError('此 HTML 尚未支援外部圖片，請先使用新版工作台程式')
    files = dict(snapshot.get('imageFiles', {}))
    pending = {}
    for image_id, data_url in images.items():
        image = re.fullmatch(r'data:image/(png|jpeg|webp|gif);base64,([A-Za-z0-9+/=]+)', data_url)
        if not image:
            raise ValueError(f'圖片格式不正確：{image_id}')
        data = base64.b64decode(image[2], validate=True)
        name = hashlib.sha256(data).hexdigest() + '.' + image[1]
        relative = 'assets/images/' + name
        files[image_id] = relative
        pending[relative] = data
    snapshot['imageBlobs'] = {}
    snapshot['imageFiles'] = files
    payload = json.dumps(snapshot, ensure_ascii=False, separators=(',', ':'))
    payload = payload.replace('<', '\\u003c').replace('>', '\\u003e').replace('&', '\\u0026')
    result = source[:match.start(2)] + payload + source[match.end(2):]
    for relative, data in pending.items():
        target = path.parent / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.read_bytes() != data:
            raise ValueError(f'圖片檔案內容衝突：{target}')
        target.write_bytes(data)
    path.write_text(result, encoding='utf-8')
    print(f'已拆出 {len(images)} 張圖片（{len(pending)} 個檔案），HTML：{len(result.encode()) / 1024:.1f} KiB')


if __name__ == '__main__':
    main()
