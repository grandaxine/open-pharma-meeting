import Foundation
import XCTest
import MeetingDataKit
import PrivacyPolicyKit

private struct PhraseDetector: LocalEntityDetector {
    let phrase: String
    let kind: IdentityKind

    func detect(in text: String, language: String) async throws -> [IdentifyingSpan] {
        let source = text as NSString
        var result: [IdentifyingSpan] = []
        var search = NSRange(location: 0, length: source.length)
        while search.length > 0 {
            let found = source.range(of: phrase, options: [], range: search)
            guard found.location != NSNotFound else { break }
            result.append(IdentifyingSpan(startUTF16: found.location, endUTF16: NSMaxRange(found), kind: kind))
            let next = NSMaxRange(found)
            search = NSRange(location: next, length: source.length - next)
        }
        return result
    }
}

final class DeidentificationTests: XCTestCase {
    private func transcript(_ text: String) -> Transcript {
        Transcript(meetingID: UUID(), language: "ru-RU", segments: [TranscriptSegment(start: 0, end: 1, text: text)])
    }

    func testApprovedModelProfilesHaveDistinctPinnedFiles() {
        XCTAssertEqual(Set(LocalModelProfile.allCases.map(\.id)), ["qwen3-0.6b-q8", "gemma3-1b-q4"])
        XCTAssertEqual(Set(LocalModelProfile.allCases.map(\.filename)).count, 2)
        XCTAssertEqual(LocalModelProfile.gemma.expectedSHA256,
                       "8ccc5cd1f1b3602548715ae25a66ed73fd5dc68a210412eea643eb20eb75a135")
        XCTAssertEqual(LocalModelProfile.gemma.sourceURL.host, "huggingface.co")
        XCTAssertTrue(LocalModelProfile.gemma.sourceURL.absoluteString.contains("ggml-org/gemma-3-1b-it-GGUF"))
    }

    func testModelSpecificPromptFramingAndIdentityScope() {
        let source = "Здравствуйте Евгений Петрович. Я Сергей. Обсудим Кискали на улице Пушкина."
        let qwen = LocalModelProfile.qwen.prompt(source: source, language: "ru-RU",
                                                 brandHints: "Кискали", nameHints: "Евгений Петрович, Сергей")
        let gemma = LocalModelProfile.gemma.prompt(source: source, language: "ru-RU",
                                                   brandHints: "Кискали", nameHints: "Евгений Петрович, Сергей")
        XCTAssertTrue(qwen.contains("/no_think"))
        XCTAssertTrue(qwen.contains("<|im_start|>"))
        XCTAssertFalse(gemma.contains("/no_think"))
        XCTAssertFalse(gemma.contains("<|im_start|>"))
        XCTAssertTrue(gemma.contains("<start_of_turn>"))
        XCTAssertTrue(gemma.contains("Кискали"))
        XCTAssertTrue(gemma.contains("улице Пушкина"))
        XCTAssertTrue(gemma.contains("представителя"))
    }

    func testDirectIdentifiersAreMasked() async throws {
        let source = transcript("Доктор Петров, телефон +7 999 123-45-67, обсуждал препарат Астразенека.")
        let draft = try await DeidentificationService.makeDraft(transcript: source, detector: PhraseDetector(phrase: "Петров", kind: .doctor))
        XCTAssertEqual(draft.redactedText, "Доктор [DOCTOR_1], телефон [CONTACT_1], обсуждал препарат Астразенека.")
    }

    func testBrandsAndClaimsRemainVerbatim() async throws {
        let source = transcript("Препарат Петров сравнили с брендом Конкурент; врач упомянул применение вне инструкции.")
        let draft = try await DeidentificationService.makeDraft(transcript: source, detector: PhraseDetector(phrase: "несуществующее имя", kind: .doctor))
        XCTAssertEqual(draft.redactedText, source.text)
    }

    func testContextualNamesDoNotMaskSameNamedBrand() async throws {
        let source = transcript("Доктор Петров обсудил препарат Петров с пациенткой Анной Сидоровой.")
        let draft = try await DeidentificationService.makeDraft(
            transcript: source, detector: PhraseDetector(phrase: "нет такого имени", kind: .doctor))
        XCTAssertEqual(draft.redactedText,
                       "Доктор [DOCTOR_1] обсудил препарат Петров с пациенткой [PATIENT_1].")
    }

    func testRepeatedNamesAndOverlappingSpans() async throws {
        let source = transcript("Врач Петров сказал, что Петров вернётся.")
        let draft = try await DeidentificationService.makeDraft(transcript: source, detector: PhraseDetector(phrase: "Петров", kind: .doctor))
        XCTAssertEqual(draft.redactedText, "Врач [DOCTOR_1] сказал, что [DOCTOR_1] вернётся.")

        struct OverlapDetector: LocalEntityDetector {
            func detect(in text: String, language: String) async throws -> [IdentifyingSpan] {
                [IdentifyingSpan(startUTF16: 0, endUTF16: 11, kind: .doctor),
                 IdentifyingSpan(startUTF16: 5, endUTF16: 11, kind: .doctor)]
            }
        }
        let overlap = try await DeidentificationService.makeDraft(
            transcript: transcript("Врач Петров"), detector: OverlapDetector())
        XCTAssertEqual(overlap.redactedText, "[DOCTOR_1]")
    }

    func testConflictingAndSplitCharacterSpansFailClosed() async {
        struct FixedDetector: LocalEntityDetector {
            let spans: [IdentifyingSpan]
            func detect(in text: String, language: String) async throws -> [IdentifyingSpan] { spans }
        }
        let conflicting = FixedDetector(spans: [
            IdentifyingSpan(startUTF16: 0, endUTF16: 6, kind: .doctor),
            IdentifyingSpan(startUTF16: 2, endUTF16: 6, kind: .patient)
        ])
        do {
            _ = try await DeidentificationService.makeDraft(transcript: transcript("Петров"), detector: conflicting)
            XCTFail("Conflicting identity kinds must block draft creation")
        } catch { }

        let split = FixedDetector(spans: [IdentifyingSpan(startUTF16: 0, endUTF16: 1, kind: .person)])
        do {
            _ = try await DeidentificationService.makeDraft(transcript: transcript("👩‍⚕️ врач"), detector: split)
            XCTFail("Split grapheme must block draft creation")
        } catch { }
    }

    func testManualEditReintroducingIdentifierBlocksApproval() async throws {
        let detector = PhraseDetector(phrase: "Петров", kind: .doctor)
        let draft = try await DeidentificationService.makeDraft(
            transcript: transcript("Доктор Петров, doctor@example.com"), detector: detector)
        XCTAssertEqual(draft.redactedText, "Доктор [DOCTOR_1], [CONTACT_1]")
        do {
            _ = try await DeidentificationService.approve(
                draft: draft, reviewedText: "Доктор Петров, [CONTACT_1]", detector: detector)
            XCTFail("Residual name must block export")
        } catch { }
        do {
            _ = try await DeidentificationService.approve(
                draft: draft, reviewedText: "Доктор [DOCTOR_1], doctor@example.com", detector: detector)
            XCTFail("Residual email must block export")
        } catch { }
    }

    func testMalformedOffsetsFailClosed() async {
        let source = transcript("Врач Петров")
        struct BadDetector: LocalEntityDetector {
            func detect(in text: String, language: String) async throws -> [IdentifyingSpan] {
                [IdentifyingSpan(startUTF16: 999, endUTF16: 1000, kind: .doctor)]
            }
        }
        do {
            _ = try await DeidentificationService.makeDraft(transcript: source, detector: BadDetector())
            XCTFail("Out-of-bounds model span must block draft creation")
        } catch { }
    }

    func testArtifactContainsOnlyApprovedTextFields() async throws {
        let source = transcript("Обсудили препарат и возражения.")
        let detector = PhraseDetector(phrase: "несуществующее имя", kind: .doctor)
        let draft = try await DeidentificationService.makeDraft(transcript: source, detector: detector)
        let artifact = try await DeidentificationService.approve(draft: draft, reviewedText: draft.redactedText, detector: detector)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(artifact)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set(["schemaVersion", "language", "text"]))
        XCTAssertEqual(object["text"] as? String, "Обсудили препарат и возражения.")
    }

    func testModelHashMismatchRejected() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("wrong model".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try ModelIntegrity.verify(url: url, expectedSHA256: String(repeating: "0", count: 64)))
    }

    func testModelResponseRejectsMalformedAndUnknownIdentity() {
        XCTAssertThrowsError(try EntityResponseParser.parse("not JSON", in: "Врач Петров"))
        XCTAssertThrowsError(try EntityResponseParser.parse("{\"entities\":[{\"quote\":\"Сидоров\",\"kind\":\"doctor\"}]}", in: "Врач Петров"))
        XCTAssertThrowsError(try EntityResponseParser.parse("{\"entities\":[{\"quote\":\"Петров\",\"kind\":\"brand\"}]}", in: "Врач Петров"))
        XCTAssertThrowsError(try EntityResponseParser.parse("{\"entities\":[{\"quote\":\"Доктор Петров обсудил препарат Конкурент.\",\"kind\":\"doctor\"}]}", in: "Доктор Петров обсудил препарат Конкурент."))
    }

    func testModelResponseMasksAllRepeatedQuotes() throws {
        let output = "{\"entities\":[{\"quote\":\"Петров\",\"kind\":\"doctor\"}]}"
        let spans = try EntityResponseParser.parse(output, in: "Врач Петров; Петров ответил")
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans.map(\.kind), [.doctor, .doctor])
    }

    func testModelResponseKeepsSameNamedDrug() throws {
        let source = "Доктор Петров обсудил препарат Петров. Позже Петров ответил Петровскому."
        let output = "{\"entities\":[{\"quote\":\"Петров\",\"kind\":\"doctor\"}]}"
        let spans = try EntityResponseParser.parse(output, in: source)
        XCTAssertEqual(spans.count, 2)
        let draft = try IdentityRules.detect(in: source)
        XCTAssertEqual(draft.count, 1)
    }

    func testModelResponsePreservesStreetNameButMasksDoctorOfSameName() throws {
        let source = "Доктор Пушкина работает на улице Пушкина."
        let output = "{\"entities\":[{\"quote\":\"Пушкина\",\"kind\":\"doctor\"}]}"
        let spans = try EntityResponseParser.parse(output, in: source)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual((source as NSString).substring(with: NSRange(location: spans[0].startUTF16,
                                                                   length: spans[0].endUTF16 - spans[0].startUTF16)), "Пушкина")
        XCTAssertEqual(spans[0].startUTF16, 7)
    }

    func testModelAddressLabelPreservesStandaloneStreetButKeepsFullAddress() throws {
        let street = "На улице Пушкина обсудили Кискали."
        let streetOnly = "{\"entities\":[{\"quote\":\"улице Пушкина\",\"kind\":\"address\"}]}"
        XCTAssertTrue(try EntityResponseParser.parse(streetOnly, in: street).isEmpty)
        let full = "Адрес врача: улица Пушкина, дом 5."
        let fullAddress = "{\"entities\":[{\"quote\":\"улица Пушкина, дом 5\",\"kind\":\"address\"}]}"
        XCTAssertEqual(try EntityResponseParser.parse(fullAddress, in: full).count, 1)
    }

    func testGreetingRulePreservesStreetWithSameName() async throws {
        let source = transcript("Здравствуйте Пушкина. Встречаемся на улице Пушкина.")
        let draft = try await DeidentificationService.makeDraft(
            transcript: source, detector: PhraseDetector(phrase: "несуществующее имя", kind: .doctor))
        XCTAssertEqual(draft.redactedText, "Здравствуйте [DOCTOR_1]. Встречаемся на улице Пушкина.")
    }

    func testLinkedFullDoctorAddressIsRemovedButUnlinkedStreetRemains() async throws {
        let source = transcript("Адрес врача: улица Пушкина, дом 5. Встречаемся на улице Пушкина и обсудим Кискали.")
        let draft = try await DeidentificationService.makeDraft(
            transcript: source, detector: PhraseDetector(phrase: "несуществующее имя", kind: .doctor))
        XCTAssertEqual(draft.redactedText,
                       "Адрес врача: [ADDRESS_1]. Встречаемся на улице Пушкина и обсудим Кискали.")
    }

    func testGreetingNameIsMaskedAtEveryMentionAndBlocksReintroduction() async throws {
        let detector = PhraseDetector(phrase: "несуществующее имя", kind: .doctor)
        let source = transcript("Здравствуйте Мариванна, я из компании Нотис. Мариванна, обсудим препарат Риго.")
        let draft = try await DeidentificationService.makeDraft(transcript: source, detector: detector)
        XCTAssertEqual(draft.redactedText,
                       "Здравствуйте [DOCTOR_1], я из компании Нотис. [DOCTOR_1], обсудим препарат Риго.")
        do {
            _ = try await DeidentificationService.approve(
                draft: draft,
                reviewedText: "Здравствуйте Мариванна, я из компании Нотис. [DOCTOR_1], обсудим препарат Риго.",
                detector: detector)
            XCTFail("A reintroduced doctor name must block export")
        } catch DeidentificationError.residualIdentifier { }
    }

    func testDoctorGivenNameLaterIsMaskedButRepresentativeAndStreetRemain() async throws {
        let source = transcript("Здравствуйте Евгений Петрович. Меня зовут Сергей, я представитель. Евгений, обсудим Кискали на улице Пушкина.")
        let draft = try await DeidentificationService.makeDraft(
            transcript: source, detector: PhraseDetector(phrase: "несуществующее имя", kind: .doctor))
        XCTAssertFalse(draft.redactedText.contains("Евгений"))
        XCTAssertTrue(draft.redactedText.contains("Сергей"))
        XCTAssertTrue(draft.redactedText.contains("Кискали на улице Пушкина"))
    }

    func testGreetingNameDoesNotMaskSameNamedDrug() async throws {
        let source = transcript("Здравствуйте Петров. Обсудим препарат Петров, затем Петров ответит.")
        let draft = try await DeidentificationService.makeDraft(
            transcript: source, detector: PhraseDetector(phrase: "нет такого имени", kind: .doctor))
        XCTAssertEqual(draft.redactedText,
                       "Здравствуйте [DOCTOR_1]. Обсудим препарат Петров, затем [DOCTOR_1] ответит.")
    }

    func testBrandLexiconContainsEverySuppliedBrandWithRussianPronunciation() {
        let expected: [String: String] = [
            "Entresto": "Энтресто", "Cosentyx": "Косентикс", "Kisqali": "Кискали",
            "Kesimpta": "Кесимпта", "Tafinlar + Mekinist": "Тафинлар", "Jakavi": "Джакави",
            "Pluvicto": "Плувикто", "Ilaris": "Иларис", "Xolair": "Ксолар",
            "Promacta / Revolade": "Промакта", "Scemblix": "Скембликс",
            "Zolgensma": "Золгенсма", "Sandostatin": "Сандостатин", "Leqvio": "Леквио",
            "Tasigna": "Тасигна", "Lutathera": "Лутатера", "Exforge": "Эксфорж",
            "Lucentis": "Луцентис", "Diovan": "Диован", "Fabhalta": "Фабхалта",
            "Rhapsido": "Рапсидо", "Vanrafia": "Ванрафия", "Itvisma": "Итвисма",
            "Aimovig": "Аймовиг", "Gilenya": "Гиления", "Glivec / Gleevec": "Гливек",
            "Afinitor / Votubia": "Афинитор", "Beovu": "Беову"
        ]
        XCTAssertEqual(BrandLexicon.entries.count, expected.count)
        for entry in BrandLexicon.entries {
            XCTAssertTrue(entry.aliases.contains(expected[entry.canonical] ?? ""), entry.canonical)
        }
        XCTAssertTrue(BrandLexicon.entries.first { $0.canonical == "Tafinlar + Mekinist" }?.aliases.contains("Мекинист") == true)
        XCTAssertTrue(BrandLexicon.entries.first { $0.canonical == "Promacta / Revolade" }?.aliases.contains("Револейд") == true)
        XCTAssertTrue(BrandLexicon.entries.first { $0.canonical == "Afinitor / Votubia" }?.aliases.contains("Вотубия") == true)
    }

    func testBrandLexiconMatchesWholeTermsWithoutTreatingThemAsNames() async throws {
        let source = "Доктор Петров обсудил Кискали и Револейд, но Кискалиев не упоминал."
        XCTAssertEqual(Set(BrandLexicon.mentionedAliases(in: source)), ["Кискали", "Револейд"])
        let draft = try await DeidentificationService.makeDraft(
            transcript: transcript(source),
            detector: PhraseDetector(phrase: "Петров", kind: .doctor))
        XCTAssertTrue(draft.redactedText.contains("Кискали и Револейд"))
        XCTAssertFalse(draft.redactedText.contains("Доктор Петров"))
    }

    func testSpokenNameLexiconRecognizesJoinedAndColloquialPatronymics() {
        let forms = Set(NameLexicon.mentionedForms(in:
            "Здравствуйте, Марьиванна. Евгенийпетрович встретил Василия Олегыча и Василийолегыч ответил."))
        XCTAssertTrue(forms.contains("Марьиванна"))
        XCTAssertTrue(forms.contains("Евгенийпетрович"))
        XCTAssertTrue(forms.contains("Василийолегыч"))
        XCTAssertTrue(NameLexicon.mentionedForms(in: "Марьиванн, подскажите").contains("Марьиванн"))
        XCTAssertFalse(NameLexicon.mentionedForms(in: "Кискали и Скембликс").contains("Кискали"))
    }

    func testGreetingMasksNamePatronymicAcrossSpokenVariants() async throws {
        let source = transcript("Здравствуйте Василий Олегович. Василийолегыч, обсудим Кискали.")
        let draft = try await DeidentificationService.makeDraft(
            transcript: source, detector: PhraseDetector(phrase: "нет имени", kind: .doctor))
        XCTAssertEqual(draft.redactedText,
                       "Здравствуйте [DOCTOR_1]. [DOCTOR_1], обсудим Кискали.")
    }

    func testCommonPatronymicAliasesKeepOneIdentity() async throws {
        let source = transcript("Добрый день Сергей Сергеевич. Сергейсергеич обсудил препарат Энтресто.")
        let draft = try await DeidentificationService.makeDraft(
            transcript: source, detector: PhraseDetector(phrase: "нет имени", kind: .doctor))
        XCTAssertEqual(draft.redactedText,
                       "Добрый день [DOCTOR_1]. [DOCTOR_1] обсудил препарат Энтресто.")
    }

    func testKnownBrandCanStillBeANameWithExplicitDoctorCue() throws {
        let source = "Доктор Кискали обсудил препарат Кискали."
        let spans = try EntityResponseParser.parse(
            "{\"entities\":[{\"quote\":\"Кискали\",\"kind\":\"doctor\"}]}", in: source)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual((source as NSString).substring(with: NSRange(
            location: spans[0].startUTF16, length: spans[0].endUTF16 - spans[0].startUTF16)), "Кискали")
    }
}
