# UX/UI Design System

Этот файл содержит полную дизайн-систему и компонентную библиотеку проекта KnowerManager.

## Структура

- `DesignTokens.swift` - Токены дизайна (spacing, radius, typography, shadows, gradients)
- `Components.swift` - Базовые компоненты (кнопки, карточки, инпуты, бейджи)
- `UXUIKit.swift` - Готовые UX-компоненты (таббар, статус-хедер, feature cards, action bar)

## Использование

Импортируйте через `import SwiftUI` в нужных View.

```swift
@Namespace private var animation
var tabs = [
  UXUIKit.ModernTabBar.TabItem(title: "Обход", icon: "network", badge: nil),
  UXUIKit.ModernTabBar.TabItem(title: "VPN", icon: "lock.shield", badge: nil),
  UXUIKit.ModernTabBar.TabItem(title: "WARP", icon: "key.fill", badge: nil),
  UXUIKit.ModernTabBar.TabItem(title: "Сканер", icon: "text.viewfinder", badge: nil),
  UXUIKit.ModernTabBar.TabItem(title: "Инструменты", icon: "wrench.and.screwdriver.fill", badge: nil),
]

UXUIKit.ModernTabBar(selectedTab: $selectedTab, tabs: tabs, namespace: animation)
```

## Рекомендации по модернизации

1. **Табы** - используйте `ModernTabBar` с `matchedGeometryEffect` для плавной анимации
2. **Кнопки** - `ModernButtonStyle` с вариантами filled/ghost/outline
3. **Карточки** - `ElevatedCard` или `GlassCard` для акцентных блоков
4. **Статус** - `UXUIKit.StatusHeader` для главного экрана
5. **Меню/мини-меню** - унифицировать отступы через `DesignTokens.Spacing`

## Цветовая схема

- Фоны: `Color(NSColor.controlBackgroundColor)`, `.ultraThinMaterial`
- Границы: `DS.strokeColor = Color(NSColor.separatorColor).opacity(0.4)`
- Акцент: синий/фиолетовый градиенты, зеленый для активного состояния

## Анимации

- `DS.spring`, `DS.springQuick`, `DS.ease` - консистентные тайминги
- `matchedGeometryEffect` для переходов
- `scaleEffect` + `opacity` для интерактивности

## Редактирование

Все значения в одном месте. Меняйте токены в `DesignTokens.swift` - изменения применятся везде.
```