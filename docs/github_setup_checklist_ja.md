# GitHub 側セットアップチェックリスト

## GitHub Pages

プライバシーポリシー公開用に GitHub Pages を有効化してください。

1. GitHubで `yamtomworks/paralarm` を開く
2. `Settings`
3. `Pages`
4. `Build and deployment`
5. `Source`: `Deploy from a branch`
6. `Branch`: `main`
7. Folder: `/docs`
8. `Save`

公開後の想定URL:

```text
https://yamtomworks.github.io/paralarm/privacy_policy.html
```

## Repository Visibility

リリース前は `Private` のままでも問題ありません。ソースを公開したい場合だけ `Public` に変更してください。

公開する場合は、以下を確認してください。

- AdMob 本番IDや個人情報を含めていないか
- 課金がデモ実装であることをREADMEやIssueで管理できているか
- ライセンスを追加するかどうか

## Issues

GitHubの `Issues` タブで、`Release checklist` テンプレートからリリース前タスクを作成してください。

作成後は以下を順番に確認すると進めやすいです。

- GitHub Pages
- AdMob本番化
- アプリ内課金本実装
- ストア画像
- iOS/Androidリリース署名

