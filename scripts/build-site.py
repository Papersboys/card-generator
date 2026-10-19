#!/usr/bin/env python3
"""Render public Markdown guides into standalone GitHub Pages documents."""
from pathlib import Path
import re
import markdown

root=Path(__file__).resolve().parent.parent
docs=root/'docs'
pages=[('USAGE.zh-CN.md','guide.html','zh-CN','使用指南','guide.en.html'),('USAGE.en.md','guide.en.html','en','User guide','guide.html'),('INSTALL.zh-CN.md','install.html','zh-CN','安装指南','install.en.html'),('INSTALL.en.md','install.en.html','en','Installation','install.html')]
route={source:target for source,target,*_ in pages}
for source,target,lang,label,other in pages:
    zh=lang=='zh-CN'
    text=(docs/source).read_text()
    text=re.sub(r'^# .+\n','',text,count=1)
    text=re.sub(r'^\[English\].*\n','',text,count=1,flags=re.M)
    for original,url in route.items():
        text=text.replace(f']({original}',f']({url}')
    renderer=markdown.Markdown(extensions=['extra','toc','sane_lists'],extension_configs={'toc':{'toc_depth':'2-3'}})
    content=renderer.convert(text)
    title=f'{label} · Link Card'
    active_zh=target if zh else other
    active_en=other if zh else target
    html=f'''<!doctype html>
<html lang="{lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title>
<meta name="description" content="{'Link Card 的安装、Visa 虚拟卡信息、创建与批准请求操作指南。' if zh else 'Install Link Card, view Visa virtual card details, and create and approve requests.'}">
<link rel="icon" type="image/png" href="site/app-icon.png"><link rel="stylesheet" href="site/style.css"><link rel="stylesheet" href="site/guide.css"></head>
<body class="guide-page"><a class="skip" href="#article">{'跳到正文' if zh else 'Skip to content'}</a>
<header class="header wrap"><a class="brand" href="index.html{'?lang=en' if not zh else ''}"><img src="site/app-icon.png" width="40" height="40" alt=""><span>Link Card</span></a>
<nav aria-label="{'导航' if zh else 'Navigation'}"><a href="index.html{'?lang=en' if not zh else ''}">{'产品主页' if zh else 'Home'}</a><a href="{'install.html' if zh else 'install.en.html'}">{'安装' if zh else 'Installation'}</a><a href="{'guide.html' if zh else 'guide.en.html'}">{'使用指南' if zh else 'User guide'}</a></nav>
<div class="header-actions"><div class="language"><a href="{active_zh}" {'aria-current="page"' if zh else ''}>中文</a><a href="{active_en}" {'aria-current="page"' if not zh else ''}>EN</a></div></div></header>
<div class="guide-title wrap"><p class="eyebrow">LINK CARD / {'文档' if zh else 'DOCUMENTATION'}</p><h1>{label}</h1><p>{'从查看卡信息，到下一笔付款请求。' if zh else 'From your card details to your next spend request.'}</p><a class="button primary" href="https://github.com/Papersboys/card-generator/releases/latest/download/LinkCard-macos-arm64.zip">{'下载 Mac 版' if zh else 'Download for Mac'} ↓</a></div>
<main class="guide-layout wrap"><aside class="guide-toc" aria-label="{'目录' if zh else 'On this page'}"><p>{'本页内容' if zh else 'ON THIS PAGE'}</p>{renderer.toc}</aside><article id="article" class="guide-article">{content}</article></main>
<footer class="footer wrap"><a class="brand" href="index.html">Link Card</a><p>{'独立开源项目 · 非 Link / Stripe 官方产品' if zh else 'Independent open-source project · Not affiliated with Link or Stripe'}</p><div><a href="https://github.com/Papersboys/card-generator">GitHub</a><a href="https://github.com/Papersboys/card-generator/blob/main/LICENSE">Apache 2.0</a></div></footer>
</body></html>'''
    (docs/target).write_text(html)
    print(f'Built {target}')
