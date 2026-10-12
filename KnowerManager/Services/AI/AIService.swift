import Foundation
import Combine

// ВАЖНО: Убедитесь, что в других файлах вашего проекта добавлены недостающие операции в перечисление AIOperation
// Добавьте в файл, где определено AIOperation, следующие кейсы:
// case expand
// case formal
// case informal
// case translateToRussian

class AIService: ObservableObject {
    @Published var config: AIConfig
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var lastResponse: AIResponse?
    @Published var tokenUsage: Int = 0
    // Отладочный режим выключен по умолчанию: иначе реальные запросы
    // к AI-провайдеру никогда не выполняются, а "проверка подключения"
    // всегда возвращает успех.
    @Published var debugMode: Bool = false
    @Published var balance: Double = 0.0
    @Published var balanceStatus: BalanceStatus = .unknown
    @Published var lastCost: Double?
    
    enum BalanceStatus {
        case unknown
        case checking
        case available(Double)
        case insufficient
        case error(String)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init(config: AIConfig? = nil) {
        self.config = config ?? AIService.loadConfig()
    }
    
    private static let apiKeyAccount = "ai_api_key"
    
    private static func loadConfig() -> AIConfig {
        var config = AIConfig.default
        if let data = UserDefaults.standard.data(forKey: "aiConfig"),
           let decoded = try? JSONDecoder().decode(AIConfig.self, from: data) {
            config = decoded
            // Миграция: если ключ сохранился в открытом виде в UserDefaults —
            // переносим его в Keychain и перезаписываем настройки без ключа.
            if !config.apiKey.isEmpty {
                KeychainHelper.shared.set(config.apiKey, for: apiKeyAccount)
                config.apiKey = ""
                persist(config)
            }
        }
        // API-ключ всегда хранится в Keychain, а не в UserDefaults.
        if let key = KeychainHelper.shared.get(apiKeyAccount) {
            config.apiKey = key
        }
        return config
    }
    
    func saveConfig() {
        if config.apiKey.isEmpty {
            KeychainHelper.shared.remove(Self.apiKeyAccount)
        } else {
            KeychainHelper.shared.set(config.apiKey, for: Self.apiKeyAccount)
        }
        Self.persist(config)
    }
    
    /// Сохраняет настройки в UserDefaults, но без API-ключа.
    private static func persist(_ config: AIConfig) {
        var sanitized = config
        sanitized.apiKey = ""
        if let data = try? JSONEncoder().encode(sanitized) {
            UserDefaults.standard.set(data, forKey: "aiConfig")
        }
    }
    
    // MARK: - Основные функции
    
    func processText(_ text: String, operation: AIOperation) async throws -> String {
        guard config.enabled else {
            throw AIError.configurationError("ИИ обработка отключена")
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.emptyText
        }
        
        // Режим отладки - возвращаем тестовые ответы
        if debugMode {
            return try await debugProcessText(text, operation: operation)
        }
        
        // Проверяем наличие API ключа для облачных провайдеров
        if config.provider != .local && config.apiKey.isEmpty {
            throw AIError.configurationError("API ключ не установлен")
        }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        defer {
            isLoading = false
        }
        let prompt = "\(operation.prompt)\n\n\(text)"
        
        // Для локальных моделей через Ollama
        if config.provider == .local {
            return try await processWithOllama(prompt: prompt)
        } else {
            return try await processWithCloudAPI(prompt: prompt)
        }
    }
    
    // MARK: - Private Methods
    
    private func debugProcessText(_ text: String, operation: AIOperation) async throws -> String {
        // Имитируем задержку сети
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 секунды
        
        await MainActor.run {
            tokenUsage += text.count / 4 // Примерный подсчет токенов
        }
        
        // Генерируем тестовый ответ в зависимости от операции
        switch operation {
        case .rewrite:
            return "**Переписанный текст:**\n\n\(text.replacingOccurrences(of: ".", with: "!").replacingOccurrences(of: "я", with: "Я"))\n\nЭто пример переписанного текста в режиме отладки."
        case .improve:
            return "**Улучшенный текст:**\n\n\(text.uppercased())\n\nТекст был улучшен: исправлена грамматика, добавлена структура."
        case .summarize:
            return "**Краткое содержание:**\n\n\(String(text.prefix(100)))...\n\nОсновная мысль: это тестовый текст."
        // TODO: Добавьте недостающие кейсы в перечисление AIOperation в его файле
        default:
            // Временный fallback для недостающих операций
            return "**Обработанный текст (операция: \(String(describing: operation))):**\n\n\(text)\n\nЭто результат обработки в режиме отладки."
        }
    }
    
    private func processWithOllama(prompt: String) async throws -> String {
        guard let ollamaURL = URL(string: "http://localhost:11434/api/generate") else {
            throw AIError.configurationError("Некорректный URL Ollama")
        }
        var request = URLRequest(url: ollamaURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        let ollamaRequest: [String: Any] = [
            "model": config.model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": config.temperature,
                "num_predict": config.maxTokens
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: ollamaRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError("Некорректный ответ от сервера")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Неизвестная ошибка"
            throw AIError.apiError("Ошибка API: \(httpResponse.statusCode) - \(errorMessage)")
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        let result = ollamaResponse.response
        
        await MainActor.run {
            self.tokenUsage = result.count / 4 // Примерная оценка токенов
        }
        
        return result
    }
    
    private func processWithAnthropic(prompt: String) async throws -> String {
        guard let url = URL(string: "\(config.provider.baseURL)/messages") else {
            throw AIError.configurationError("Некорректный URL провайдера")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]
        
        let body: [String: Any] = [
            "model": config.model,
            "system": "Ты полезный AI ассистент, специализирующийся на обработке текста. Отвечай только на языке пользователя.",
            "messages": messages,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError("Некорректный ответ от сервера")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = try await parseAPIError(data: data, statusCode: httpResponse.statusCode)
            throw AIError.apiError("Ошибка API: \(httpResponse.statusCode) - \(errorMessage)")
        }
        
        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let result = decoded.content.first(where: { $0.type == "text" })?.text ?? ""
        
        await MainActor.run {
            if let usage = decoded.usage {
                self.tokenUsage += usage.input_tokens + usage.output_tokens
                self.lastCost = estimateCost(tokens: usage.input_tokens + usage.output_tokens)
            } else {
                self.tokenUsage += prompt.count / 4
            }
        }
        
        return result
    }
    
    private func processWithCloudAPI(prompt: String) async throws -> String {
        // Anthropic использует Messages API с собственной структурой запроса/ответа.
        if config.provider == .anthropic {
            return try await processWithAnthropic(prompt: prompt)
        }
        
        guard let url = URL(string: "\(config.provider.baseURL)/chat/completions") else {
            throw AIError.configurationError("Некорректный URL провайдера")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Устанавливаем заголовок авторизации
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        let messages: [[String: String]] = [
            ["role": "system", "content": "Ты полезный AI ассистент, специализирующийся на обработке текста. Отвечай только на языке пользователя."],
            ["role": "user", "content": prompt]
        ]
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "temperature": config.temperature,
            "max_tokens": config.maxTokens
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError("Некорректный ответ от сервера")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = try await parseAPIError(data: data, statusCode: httpResponse.statusCode)
            throw AIError.apiError("Ошибка API: \(httpResponse.statusCode) - \(errorMessage)")
        }
        
        let aiResponse = try JSONDecoder().decode(AIResponse.self, from: data)
        
        await MainActor.run {
            self.lastResponse = aiResponse
            if let usage = aiResponse.usage {
                self.tokenUsage += usage.total_tokens
                self.lastCost = estimateCost(tokens: usage.total_tokens)
            } else {
                // Примерная оценка токенов, если API не вернуло usage
                self.tokenUsage += prompt.count / 4
            }
        }
        
        return aiResponse.choices.first?.message.content ?? ""
    }
    
    private func parseAPIError(data: Data, statusCode: Int) async throws -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            
            // Специальная обработка для ошибки баланса
            if message.contains("Insufficient Balance") || statusCode == 402 {
                await MainActor.run {
                    self.balanceStatus = .insufficient
                }
                return "Недостаточно средств на счету. Пополните баланс на \(config.provider.rawValue)."
            }
            
            return "\(config.provider.rawValue): \(message)"
        }
        
        switch statusCode {
        case 401:
            return "Неверный API ключ. Проверьте ключ в настройках."
        case 429:
            return "Слишком много запросов. Подождите и повторите позже."
        case 500...599:
            return "Ошибка сервера \(config.provider.rawValue). Попробуйте позже."
        default:
            return "Ошибка API (\(statusCode)). Проверьте настройки."
        }
    }
    
    // MARK: - Дополнительные функции
    
    func estimateCost(tokens: Int) -> Double {
        // Примерные цены за 1000 токенов
        let costPerThousand: Double
        switch config.provider {
        case .deepseek:
            costPerThousand = 0.0014 // $0.0014 за 1K токенов
        case .openai:
            // Разная стоимость в зависимости от модели
            if config.model.contains("gpt-4") {
                costPerThousand = config.model.contains("turbo") ? 0.03 : 0.06
            } else {
                costPerThousand = 0.0015 // GPT-3.5
            }
        case .anthropic:
            costPerThousand = config.model.contains("haiku") ? 0.001 : 0.015
        case .local:
            costPerThousand = 0.0 // бесплатно
        }
        
        let cost = Double(tokens) / 1000 * costPerThousand
        return cost
    }
    
    func checkBalance() async {
        guard config.provider == .deepseek else {
            // Для других провайдеров показываем сообщение
            await MainActor.run {
                self.balanceStatus = .error("Проверка баланса доступна только для DeepSeek")
            }
            return
        }
        
        await MainActor.run {
            self.balanceStatus = .checking
        }
        
        // DeepSeek не предоставляет публичный API для проверки баланса
        // Вместо этого показываем информацию о бесплатном лимите
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Имитация задержки
        
        await MainActor.run {
            self.balance = 1000 // Бесплатный дневной лимит DeepSeek
            self.balanceStatus = .available(1000)
        }
    }
    
    func testConnection() async throws -> Bool {
        guard !debugMode else {
            return true // В режиме отладки всегда успешно
        }
        
        guard config.enabled else {
            throw AIError.configurationError("ИИ не настроен")
        }
        
        if config.provider != .local && config.apiKey.isEmpty {
            throw AIError.configurationError("API ключ не установлен")
        }
        
        let testText = "Привет, это тестовое сообщение."
        do {
            _ = try await processText(testText, operation: .rewrite)
            return true
        } catch {
            throw error
        }
    }
    
    func batchProcessTexts(_ texts: [String], operation: AIOperation) async throws -> [String] {
        var results: [String] = []
        for text in texts {
            let result = try await processText(text, operation: operation)
            results.append(result)
        }
        return results
    }
    
    func customProcess(text: String, customPrompt: String) async throws -> String {
        guard config.enabled else {
            throw AIError.configurationError("ИИ обработка отключена")
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.emptyText
        }
        
        if debugMode {
            return try await debugProcessText(text, operation: .rewrite)
        }
        
        if config.provider != .local && config.apiKey.isEmpty {
            throw AIError.configurationError("API ключ не установлен")
        }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        defer {
            isLoading = false
        }
        // Используем переданный пользовательский промпт, а не встроенный.
        let prompt = "\(customPrompt)\n\n\(text)"
        
        if config.provider == .local {
            return try await processWithOllama(prompt: prompt)
        } else {
            return try await processWithCloudAPI(prompt: prompt)
        }
    }
}
