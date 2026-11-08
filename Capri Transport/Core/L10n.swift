import Foundation

enum Lang: String, CaseIterable, Identifiable {
    case uk, en, it, fr, de        // порядок = порядок колонок у таблиці нижче
    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    static var system: Lang {
        Lang(rawValue: Locale.current.language.languageCode?.identifier ?? "en") ?? .en
    }
}

struct L10n {
    let lang: Lang

    func callAsFunction(_ key: String) -> String {
        guard let row = Self.table[key], let i = Lang.allCases.firstIndex(of: lang) else { return key }
        return row[i]
    }

    func place(_ p: PlaceID) -> String { self("p." + p.rawValue) }
    func name(_ r: Route) -> String { "\(place(r.from)) → \(place(r.to))" }

    func until(_ minutes: Int) -> String {
        if minutes <= 0 { return self("now") }
        var parts = [self("in")]
        if minutes / 60 > 0 { parts.append("\(minutes / 60) \(self("h"))") }
        if minutes % 60 > 0 { parts.append("\(minutes % 60) \(self("m"))") }
        return parts.joined(separator: " ")
    }

    func info(_ r: Route, withOperators: Bool = true) -> String {
        var parts: [String] = []
        if withOperators, !r.operators.isEmpty { parts.append(r.operators) }
        if let k = r.kind, let m = r.durationMin { parts.append("\(self(k.rawValue)) · ~\(m) \(self("m"))") }
        if let p = r.price {
            parts.append(p.formatted(.currency(code: "EUR").locale(lang.locale)))
        }
        return parts.joined(separator: " · ")
    }

    func date(_ d: Date, _ template: String) -> String {
        let f = DateFormatter()
        f.locale = lang.locale
        f.timeZone = Rome.calendar.timeZone
        f.setLocalizedDateFormatFromTemplate(template)
        return f.string(from: d)
    }

    // uk, en, it, fr, de
    static let table: [String: [String]] = [
        "title":    ["Капрі: розклад", "Capri timetable", "Orari Capri", "Horaires Capri", "Fahrplan Capri"],
        "theme.title": ["Оформлення", "Appearance", "Aspetto", "Apparence", "Erscheinungsbild"],
        "theme.preset": ["Палітра", "Color palette", "Palette", "Palette", "Farbpalette"],
        "theme.preset.sea": ["Море (за замовч.)", "Sea (default)", "Mare (predefinito)", "Mer (défaut)", "Meer (Standard)"],
        "theme.preset.terracotta": ["Теракота", "Terracotta", "Terracotta", "Terracotta", "Terrakotta"],
        "theme.preset.olive": ["Олива", "Olive", "Ulivo", "Olive", "Olive"],
        "theme.preset.dusk": ["Сутінки", "Dusk", "Crepuscolo", "Crépuscule", "Dämmerung"],
        "theme.preset.midnight": ["Північ", "Midnight", "Mezzanotte", "Minuit", "Mitternacht"],
        "theme.scheme": ["Тема", "Theme", "Tema", "Thème", "Modus"],
        "theme.scheme.system": ["Система", "System", "Sistema", "Système", "System"],
        "theme.scheme.light": ["Світла", "Light", "Chiaro", "Clair", "Hell"],
        "theme.scheme.dark": ["Темна", "Dark", "Scuro", "Sombre", "Dunkel"],
        "theme.reset": ["Скинути оформлення", "Reset appearance", "Ripristina aspetto", "Réinitialiser", "Zurücksetzen"],
        "theme.note": ["Акцент і картки оновлюються одразу. Налаштування зберігаються на пристрої.", "Accent and cards update instantly. Settings are saved on device.", "Accento e schede si aggiornano subito. Salvato sul dispositivo.", "L’accentuation se met à jour tout de suite. Enregistré sur l’appareil.", "Akzent und Karten aktualisieren sich sofort. Auf dem Gerät gespeichert."],
        "tt.from":  ["Відправлення", "Departure", "Partenza", "Départ", "Abfahrt"],
        "tt.to":    ["Прибуття", "Arrival", "Arrivo", "Arrivée", "Ankunft"],
        "tt.service": ["Лінія / тип судна", "Service / vessel", "Servizio / nave", "Ligne / bateau", "Linie / Schiff"],
        "clock":    ["Зараз на Капрі", "Time on Capri", "Ora a Capri", "Heure à Capri", "Uhrzeit auf Capri"],
        "now":      ["зараз", "now", "ora", "maintenant", "jetzt"],
        "gone":     ["відправився", "departed", "partito", "parti", "abgefahren"],
        "done":     ["На сьогодні все", "No more departures today", "Nessuna partenza per oggi", "Plus de départs aujourd’hui", "Heute keine Abfahrten mehr"],
        "nextDep":  ["Наступний рейс", "Next departure", "Prossima partenza", "Prochain départ", "Nächste Abfahrt"],
        "in":       ["через", "in", "tra", "dans", "in"],
        "h":        ["год", "h", "h", "h", "Std"],
        "m":        ["хв", "min", "min", "min", "Min"],
        "none":     ["Немає рейсів", "No service", "Nessun servizio", "Pas de service", "Kein Betrieb"],
        "count":    ["Рейсів", "Departures", "Corse", "Départs", "Abfahrten"],
        "today":    ["Сьогодні", "Today", "Oggi", "Aujourd’hui", "Heute"],
        "tomorrow": ["Завтра", "Tomorrow", "Domani", "Demain", "Morgen"],
        "arrival":  ["Прибуття", "Arrival", "Arrivo", "Arrivée", "Ankunft"],
        "close":    ["Закрити", "Close", "Chiudi", "Fermer", "Schließen"],
        "openGM":   ["Відкрити в Google Maps", "Open in Google Maps", "Apri in Google Maps", "Ouvrir dans Google Maps", "In Google Maps öffnen"],
        "openAM":   ["Відкрити в Apple Maps", "Open in Apple Maps", "Apri in Apple Maps", "Ouvrir dans Plans", "In Apple Karten öffnen"],
        "buyTicket": ["Купити квиток", "Buy ticket", "Acquista biglietto", "Acheter un billet", "Ticket kaufen"],
        "ticketNote": ["Посилання на сайт перевізника — перевірте ціну й наявність перед покупкою.",
                      "Link to the operator’s website — check price and availability before purchasing.",
                      "Link al sito del vettore — verifica prezzo e disponibilità prima dell’acquisto.",
                      "Lien vers le site du transporteur — vérifiez prix et disponibilité avant d’acheter.",
                      "Link zur Betreiberwebsite — Preis und Verfügbarkeit vor dem Kauf prüfen."],
        "tip":      ["Натисніть на час відправлення, щоб побачити маршрут на карті.",
                     "Tap a departure time to see the route on the map.",
                     "Tocca un orario di partenza per vedere il percorso sulla mappa.",
                     "Touchez une heure de départ pour voir l’itinéraire sur la carte.",
                     "Tippen Sie auf eine Abfahrtszeit, um die Route auf der Karte zu sehen."],
        "offline.banner": ["Без мережі — розклад доступний офлайн.",
                           "Offline — timetable works without a connection.",
                           "Offline: gli orari restano disponibili senza rete.",
                           "Hors ligne — horaires disponibles sans connexion.",
                           "Offline — Fahrplan ohne Verbindung verfügbar."],
        "offline.maps":   ["Карти та навігація потребують інтернету.",
                           "Maps and directions need an internet connection.",
                           "Mappe e indicazioni richiedono internet.",
                           "Cartes et itinéraires nécessitent internet.",
                           "Karten und Navigation brauchen eine Internetverbindung."],
        "data.banner.title": ["Демо-розклад", "Demo timetable", "Orari dimostrativi", "Horaires démo", "Demo-Fahrplan"],
        "data.banner.body": ["Перевіряйте час на сайті перевізника перед поїздкою. У штормові дні рейси можуть скасовувати.", "Verify times on the operator’s site before travelling. Services may be cancelled in rough weather.", "Verifica gli orari sul sito del vettore. In mare mosso le corse possono essere sospese.", "Vérifiez les horaires sur le site du transporteur. Annulations possibles par gros temps.", "Zeiten beim Betreiber prüfen. Bei Unwetter Ausfälle möglich."],
        "about.title": ["Про дані", "About data", "Informazioni dati", "À propos des données", "Über die Daten"],
        "about.data": ["Розклад", "Timetable", "Orari", "Horaires", "Fahrplan"],
        "about.updated": ["Оновлено в застосунку", "Bundle updated", "Aggiornato nell’app", "Mis à jour dans l’app", "Im Bundle aktualisiert"],
        "about.routes": ["Маршрутів", "Routes", "Percorsi", "Lignes", "Routen"],
        "about.sights": ["Пам’ятки", "Sights", "Luoghi", "Sites", "Sehenswürdigkeiten"],
        "about.sights.updated": ["Пам’ятки оновлено", "Sights bundle", "Luoghi aggiornati", "Sites (bundle)", "Sehenswürdigkeiten"],
        "about.deeplink": ["Посилання в застосунок", "In-app links", "Link interni", "Liens internes", "App-Links"],
        "about.deeplink.hint": ["Формат: capritransport://route/ID маршруту або capritransport://tab/schedule|sights|travels", "Format: capritransport://route/ROUTE_ID or capritransport://tab/schedule|sights|travels", "Formato: capritransport://route/ID o capritransport://tab/...", "Format : capritransport://route/ID ou capritransport://tab/...", "Format: capritransport://route/ID oder capritransport://tab/..."],
        "about.deeplink.share": ["Посилання на маршрут", "Route link", "Link percorso", "Lien ligne", "Routen-Link"],
        "schedule.favorites.next": ["Найближчі обрані рейси", "Next favorite departures", "Prossime corse preferite", "Prochains favoris", "Nächste Favoriten"],
        "travel.privacy.signedIn": ["Вихід видаляє лише сесію на пристрої; історії залишаються локально.", "Sign out clears this device’s session; stories stay local.", "Esci solo su questo dispositivo; i post restano in locale.", "Déconnexion locale uniquement ; les récits restent sur l’appareil.", "Abmeldung nur lokal; Beiträge bleiben auf dem Gerät."],
        "about.sources": ["Джерела", "Sources", "Fonti", "Sources", "Quellen"],
        "about.sources.body": ["Посилання на квитки ведуть на сайти перевізників (NLG, SNAV, Caremar, ATC тощо). Фото пам’яток — у розділі авторських прав.", "Ticket links open operator websites (NLG, SNAV, Caremar, ATC, etc.). Sight photos are credited separately.", "I biglietti aprono i siti dei vettori. Foto nella sezione crediti.", "Billets vers les sites des transporteurs. Photos créditées à part.", "Tickets zu Betreiberwebsites. Fotos unter Credits."],
        "about.travel": ["Подорожі", "Travels", "Viaggi", "Voyages", "Reisen"],
        "share.departure": ["Поділитися рейсом", "Share departure", "Condividi corsa", "Partager départ", "Abfahrt teilen"],
        "favorite.add": ["Додати в обране", "Add favorite", "Aggiungi preferito", "Ajouter favori", "Favorit hinzufügen"],
        "favorite.remove": ["Прибрати з обраного", "Remove favorite", "Rimuovi preferito", "Retirer favori", "Favorit entfernen"],
        "travel.privacy.keychain": ["Паролі — лише хеш у Keychain на цьому пристрої, без серверної синхронізації.", "Passwords are hashed in the Keychain on this device only — no cloud sync.", "Password hash nel Keychain locale, nessuna sync cloud.", "Mot de passe haché dans le trousseau local, pas de cloud.", "Passwort-Hash nur lokal in der Keychain, kein Cloud-Sync."],
        "note":     ["Демонстраційні дані по Італії (переважно Тірренське море й Капрі). Замініть актуальним розкладом перевізників і перевіряйте скасування при поганій погоді.",
                     "Demo data for Italy (mainly Tyrrhenian routes to Capri). Replace with current operator timetables and check for cancellations in rough weather.",
                     "Dati dimostrativi per l’Italia (rotte tirreniche verso Capri). Sostituisci con orari ufficiali e verifica le sospensioni.",
                     "Données démo pour l’Italie (liaisons tyrrhéniennes vers Capri). Remplacez par les horaires officiels.",
                     "Demo für Italien (Tyrrhenrouten nach Capri). Durch offizielle Fahrpläne ersetzen und Ausfälle prüfen."],
        "ships":     ["Кораблі", "Ships", "Navi", "Bateaux", "Schiffe"],
        "buses":     ["Автобуси", "Buses", "Autobus", "Bus", "Busse"],
        "cat":      ["Катамаран", "Catamaran", "Catamarano", "Catamaran", "Katamaran"],
        "hyd":      ["Підводні крила", "Hydrofoil", "Aliscafo", "Hydroglisseur", "Tragflügelboot"],
        "p.naples":   ["Неаполь", "Naples", "Napoli", "Naples", "Neapel"],
        "p.procida":  ["Прочіда", "Procida", "Procida", "Procida", "Procida"],
        "p.ischia":   ["Іскʼя", "Ischia", "Ischia", "Ischia", "Ischia"],
        "p.sorrento": ["Сорренто", "Sorrento", "Sorrento", "Sorrente", "Sorrent"],
        "p.positano": ["Позітано", "Positano", "Positano", "Positano", "Positano"],
        "p.amalfi":   ["Амальфі", "Amalfi", "Amalfi", "Amalfi", "Amalfi"],
        "p.salerno":  ["Салерно", "Salerno", "Salerno", "Salerno", "Salerno"],
        "p.capri":    ["Капрі", "Capri", "Capri", "Capri", "Capri"],
        "p.mg":       ["Marina Grande", "Marina Grande", "Marina Grande", "Marina Grande", "Marina Grande"],
        "p.mp":       ["Marina Piccola", "Marina Piccola", "Marina Piccola", "Marina Piccola", "Marina Piccola"],
        "p.ana":      ["Анакапрі", "Anacapri", "Anacapri", "Anacapri", "Anacapri"],

        // Вкладки
        "tab.schedule": ["Розклад", "Timetable", "Orari", "Horaires", "Fahrplan"],
        "tab.sights":   ["Визначні місця", "Sights", "Luoghi da visitare", "Sites à voir", "Sehenswürdigkeiten"],
        "tab.travels":  ["Подорожі", "Travels", "Viaggi", "Voyages", "Reisen"],
        "travel.title": ["Подорожі на Капрі", "Capri travels", "Viaggi a Capri", "Voyages à Capri", "Reisen nach Capri"],
        "travel.feed.title": ["Стрічка спільноти", "Community feed", "Feed della community", "Fil de la communauté", "Community-Feed"],
        "travel.feed.subtitle": ["Історії всіх зареєстрованих користувачів на цьому пристрої — найновіші зверху.", "Stories from all registered users on this device — newest first.", "Storie di tutti gli utenti registrati su questo dispositivo — le più recenti in alto.", "Récits de tous les utilisateurs inscrits sur cet appareil — les plus récents en haut.", "Reisen aller registrierten Nutzer auf diesem Gerät — neueste zuerst."],
        "travel.like": ["Вподобати", "Like", "Mi piace", "J’aime", "Gefällt mir"],
        "travel.comments": ["Коментарі", "Comments", "Commenti", "Commentaires", "Kommentare"],
        "travel.comment.empty": ["Ще немає коментарів. Будьте першими.", "No comments yet. Be the first.", "Nessun commento. Sii il primo.", "Pas encore de commentaires. Soyez le premier.", "Noch keine Kommentare. Sei der Erste."],
        "travel.comment.placeholder": ["Напишіть коментар…", "Write a comment…", "Scrivi un commento…", "Écrire un commentaire…", "Kommentar schreiben…"],
        "travel.comment.post": ["Надіслати", "Post", "Invia", "Publier", "Senden"],
        "travel.comment.signIn": ["Увійдіть, щоб коментувати", "Sign in to comment", "Accedi per commentare", "Connectez-vous pour commenter", "Anmelden zum Kommentieren"],
        "travel.error.emptyComment": ["Коментар не може бути порожнім.", "Comment cannot be empty.", "Il commento non può essere vuoto.", "Le commentaire ne peut pas être vide.", "Kommentar darf nicht leer sein."],
        "travel.error.emptyTitle": ["Додайте заголовок історії.", "Add a story title.", "Inserisci un titolo.", "Ajoutez un titre.", "Bitte einen Titel eingeben."],
        "travel.guest.intro": ["Створіть обліковий запис, щоб публікувати власні історії з фото й описом.", "Create an account to publish your stories with photos and descriptions.", "Crea un account per pubblicare le tue storie con foto e descrizione.", "Créez un compte pour publier vos récits avec photos et description.", "Erstelle ein Konto, um Reiseberichte mit Fotos und Text zu teilen."],
        "travel.guest.note": ["Стрічка зберігається на цьому пристрої. Експортуйте історію кнопкою «Поділитися»; синхронізація в хмарі — наступний крок.", "The feed is stored on this device. Export a story with Share; cloud sync is a future step.", "Il feed è sul dispositivo. Esporta con Condividi; la sincronizzazione cloud arriverà dopo.", "Le fil est locale sur l’appareil. Exportez avec Partager ; la synchro cloud viendra ensuite.", "Der Feed liegt auf diesem Gerät. Mit Teilen exportieren; Cloud-Sync folgt später."],
        "travel.register": ["Зареєструватися", "Register", "Registrati", "S’inscrire", "Registrieren"],
        "travel.signIn": ["Увійти", "Sign in", "Accedi", "Se connecter", "Anmelden"],
        "travel.signOut": ["Вийти", "Sign out", "Esci", "Se déconnecter", "Abmelden"],
        "travel.new": ["Нова історія", "New story", "Nuova storia", "Nouveau récit", "Neue Reise"],
        "travel.publish": ["Опублікувати", "Publish", "Pubblica", "Publier", "Veröffentlichen"],
        "travel.empty.title": ["Поки немає історій", "No stories yet", "Nessuna storia", "Aucun récit", "Noch keine Reisen"],
        "travel.empty.hint": ["Розкажіть про свій візит на Капрі — додайте фото з галереї.", "Share your Capri visit — add photos from your library.", "Racconta la tua visita a Capri — aggiungi foto dalla libreria.", "Racontez votre visite à Capri — ajoutez des photos.", "Erzähle von deinem Capri-Besuch — Fotos aus der Mediathek."],
        "travel.field.title": ["Заголовок", "Title", "Titolo", "Titre", "Titel"],
        "travel.field.title.placeholder": ["Наприклад: День біля Фарагіоні", "e.g. A day at the Faraglioni", "es. Una giornata ai Faraglioni", "ex. Journée aux Faraglioni", "z. B. Tag an den Faraglioni"],
        "travel.field.body": ["Опис", "Description", "Descrizione", "Description", "Beschreibung"],
        "travel.field.photos": ["Фото", "Photos", "Foto", "Photos", "Fotos"],
        "travel.field.name": ["Ім’я", "Display name", "Nome", "Nom affiché", "Anzeigename"],
        "travel.field.name.placeholder": ["Як вас бачать інші", "How others see you", "Come ti vedono gli altri", "Nom visible aux autres", "So sehen dich andere"],
        "travel.field.email": ["Ел. пошта", "Email", "Email", "E-mail", "E-Mail"],
        "travel.field.password": ["Пароль", "Password", "Password", "Mot de passe", "Passwort"],
        "travel.field.password.placeholder": ["Щонайменше 6 символів", "At least 6 characters", "Almeno 6 caratteri", "Au moins 6 caractères", "Mindestens 6 Zeichen"],
        "travel.auth.note": ["Облікові записи й історії зберігаються локально на пристрої (демо без сервера).", "Accounts and stories are stored locally on device (demo, no server).", "Account e storie sono salvati localmente (demo senza server).", "Comptes et récits locaux sur l’appareil (démo sans serveur).", "Konten und Reisen lokal auf dem Gerät (Demo ohne Server)."],
        "travel.share": ["Поділитися", "Share", "Condividi", "Partager", "Teilen"],
        "travel.share.footer": ["Опубліковано в Capri Transport", "Published in Capri Transport", "Pubblicato in Capri Transport", "Publié dans Capri Transport", "Veröffentlicht in Capri Transport"],
        "travel.delete": ["Видалити", "Delete", "Elimina", "Supprimer", "Löschen"],
        "travel.delete.confirm": ["Видалити історію", "Delete story", "Elimina storia", "Supprimer le récit", "Reise löschen"],
        "travel.story.missing": ["Історію не знайдено", "Story not found", "Storia non trovata", "Récit introuvable", "Reise nicht gefunden"],
        "travel.error.generic": ["Щось пішло не так. Спробуйте ще раз.", "Something went wrong. Try again.", "Qualcosa è andato storto. Riprova.", "Une erreur s’est produite. Réessayez.", "Etwas ist schiefgelaufen. Bitte erneut versuchen."],
        "travel.error.emailTaken": ["Такий email уже зареєстровано.", "This email is already registered.", "Questa email è già registrata.", "Cet e-mail est déjà enregistré.", "Diese E-Mail ist bereits registriert."],
        "travel.error.credentials": ["Невірний email або пароль.", "Incorrect email or password.", "Email o password non corretti.", "E-mail ou mot de passe incorrect.", "E-Mail oder Passwort falsch."],
        "travel.error.weakPassword": ["Пароль надто короткий (мін. 6 символів).", "Password too short (min. 6 characters).", "Password troppo corta (min. 6 caratteri).", "Mot de passe trop court (min. 6 car.).", "Passwort zu kurz (min. 6 Zeichen)."],
        "travel.error.name": ["Введіть ім’я (мін. 2 символи).", "Enter a display name (min. 2 characters).", "Inserisci un nome (min. 2 caratteri).", "Nom affiché requis (min. 2 car.).", "Anzeigename eingeben (min. 2 Zeichen)."],
        "travel.error.email": ["Перевірте адресу email.", "Check your email address.", "Controlla l’indirizzo email.", "Vérifiez l’adresse e-mail.", "E-Mail-Adresse prüfen."],
        "sights.route": ["Маршрут", "Route", "Percorso", "Itinéraire", "Route"],
        "sights.routeMap.hint": ["Приблизний шлях транспортом і до точки на карті (пішки — пряма лінія).", "Approximate transport path and straight segment to the map pin (walk shown as a direct line).", "Percorso indicativo e segmento retto al punto sulla mappa (a piedi in linea retta).", "Tracé approximatif et segment direct vers le repère (marche en ligne droite).", "Ungefährer Verlauf und direkte Linie zum Kartenpunkt (Fußweg gerade)."],
        "sights.routeMap.a11y": ["Карта маршруту до місця", "Route map to destination", "Mappa del percorso verso la destinazione", "Carte de l’itinéraire vers le site", "Routenkarte zum Ziel"],
        "sights.arrivalAt": ["Прибуття", "Arrival", "Arrivo", "Arrivée", "Ankunft"],
        "sights.arrival.hint": ["Орієнтовно від Marina Grande сьогодні: найближчі рейси розкладу + пішки/черга.", "Estimate from Marina Grande today: next scheduled legs plus walk/wait time.", "Stima da Marina Grande oggi: prossime corse orarie più cammino/attesa.", "Estimation depuis Marina Grande aujourd’hui : prochains départs + marche/attente.", "Schätzung ab Marina Grande heute: nächste planmäßige Teilstrecken plus Fußweg/Wartezeit."],
        "sights.noService": ["Сьогодні рейсів не знайдено", "No departures found for today", "Nessuna corsa oggi", "Pas de départ aujourd’hui", "Heute keine Abfahrten"],
        "sights.how":   ["Як дістатися", "How to get there", "Come arrivare", "Comment s’y rendre", "Anreise"],
        "sights.showTimetable": ["Показати розклад", "Show timetable", "Mostra orari", "Voir les horaires", "Fahrplan anzeigen"],
        "sights.search": ["Пошук місць", "Search places", "Cerca luoghi", "Rechercher un lieu", "Orte suchen"],
        "sights.filter.all": ["Усе", "All", "Tutti", "Tout", "Alle"],
        "sights.cat.landmark": ["Пам’ятки", "Landmarks", "Monumenti", "Monuments", "Sehenswürdigkeiten"],
        "sights.cat.restaurant": ["Ресторани", "Restaurants", "Ristoranti", "Restaurants", "Restaurants"],
        "sights.cat.beach": ["Пляжі", "Beaches", "Spiagge", "Plages", "Strände"],
        "sights.cat.viewpoint": ["Краєвиди", "Viewpoints", "Panorami", "Points de vue", "Aussichten"],
        "sights.photosOffline": ["Фото в додатку (офлайн).", "Photos are bundled in the app (offline).", "Foto incluse nell’app (offline).", "Photos intégrées à l’app (hors ligne).", "Fotos sind in der App enthalten (offline)."],
        "sights.photoCredit": ["Фото: учасники Wikimedia Commons (перевірте ліцензії перед релізом).", "Photos: Wikimedia Commons contributors (check licenses before release).", "Foto: contributori di Wikimedia Commons (verifica le licenze prima del rilascio).", "Photos : contributeurs Wikimedia Commons (vérifiez les licences avant publication).", "Fotos: Wikimedia-Commons-Mitwirkende (Lizenzen vor Veröffentlichung prüfen)."],
        "sights.photoStrip": ["Острів очима фото", "Capri in photos", "Capri in foto", "Capri en images", "Capri in Bildern"],
        "sights.photoStrip.hint": ["Прокрутіть і оберіть місце", "Scroll and tap a place", "Scorri e tocca un luogo", "Faites défiler et touchez un lieu", "Wischen und Ort antippen"],
        "sights.credits.title": ["Ліцензії фото", "Photo licenses", "Licenze foto", "Licences des photos", "Fotolizenzen"],
        "sights.credits.intro": ["Усі знімки з Wikimedia Commons. Для App Store вкажіть авторів і умови ліцензій (CC BY / CC BY-SA).",
                                 "All images from Wikimedia Commons. For App Store release, list authors and license terms (CC BY / CC BY-SA).",
                                 "Tutte le immagini da Wikimedia Commons. Per l’App Store, indica autori e licenze (CC BY / CC BY-SA).",
                                 "Toutes les images proviennent de Wikimedia Commons. Pour l’App Store, indiquez auteurs et licences (CC BY / CC BY-SA).",
                                 "Alle Bilder von Wikimedia Commons. Für den App Store Autoren und Lizenzen angeben (CC BY / CC BY-SA)."],
        "sights.credits.license": ["Ліцензія", "License", "Licenza", "Licence", "Lizenz"],
        "sights.credits.artist": ["Автор", "Author", "Autore", "Auteur", "Urheber"],
        "sights.credits.commons": ["Сторінка на Commons", "Commons file page", "Pagina su Commons", "Page Commons", "Commons-Datei"],
        "sights.credits.sa": ["Потрібна атрибуція; поширення похідних — на тих самих умовах (SA).",
                              "Attribution required; derivatives must use the same license (SA).",
                              "Attribuzione obbligatoria; opere derivate stessa licenza (SA).",
                              "Attribution requise ; partage à l’identique pour les dérivés (SA).",
                              "Namensnennung erforderlich; Weitergabe unter gleichen Bedingungen (SA)."],
        "sights.credits.unverified": ["Не перевірено — підтвердіть на Commons", "Unverified — confirm on Commons", "Non verificato — controlla su Commons", "Non vérifié — confirmer sur Commons", "Nicht geprüft — auf Commons bestätigen"],
        "sights.note":  ["Час і маршрути орієнтовні, піни на карті наближені, а вхід до Grotta Azzurra залежить від погоди та хвилювання моря.",
                         "Times and routes are approximate, map pins are approximate, and entry to Grotta Azzurra depends on weather and sea conditions.",
                         "Tempi e percorsi sono indicativi, i segnaposto sulla mappa sono approssimativi e l’accesso alla Grotta Azzurra dipende da meteo e mare.",
                         "Durées et itinéraires approximatifs, repères de carte approximatifs ; l’accès à la Grotte d’Azur dépend de la météo et de la mer.",
                         "Zeiten und Routen sind ungefähr, die Kartenpunkte nur angenähert; der Zugang zur Blauen Grotte hängt von Wetter und Seegang ab."],
        // Кроки дороги
        "st.arrive":   ["Прибуття в Marina Grande (головний порт Капрі)", "Arrive at Marina Grande (Capri’s main port)", "Arrivo a Marina Grande (porto principale di Capri)", "Arrivée à Marina Grande (port principal de Capri)", "Ankunft in Marina Grande (Haupthafen von Capri)"],
        "st.busAna":   ["Автобус Marina Grande → Анакапрі (ATC)", "Bus Marina Grande → Anacapri (ATC)", "Autobus Marina Grande → Anacapri (ATC)", "Bus Marina Grande → Anacapri (ATC)", "Bus Marina Grande → Anacapri (ATC)"],
        "st.busGrotta":["Автобус Анакапрі → Grotta Azzurra", "Bus Anacapri → Grotta Azzurra", "Autobus Anacapri → Grotta Azzurra", "Bus Anacapri → Grotta Azzurra", "Bus Anacapri → Grotta Azzurra"],
        "st.busFaro":  ["Автобус Анакапрі → Punta Carena", "Bus Anacapri → Punta Carena", "Autobus Anacapri → Punta Carena", "Bus Anacapri → Punta Carena", "Bus Anacapri → Punta Carena"],
        "st.chairlift":["Крісельний підйомник від Piazza Vittoria (~12 хв)", "Chairlift from Piazza Vittoria (~12 min)", "Seggiovia da Piazza Vittoria (~12 min)", "Télésiège depuis la Piazza Vittoria (~12 min)", "Sessellift ab Piazza Vittoria (~12 Min)"],
        "st.walk":     ["Пішки ~%d хв", "Walk ~%d min", "A piedi ~%d min", "À pied ~%d min", "Zu Fuß ~%d Min"],
        "st.boat":     ["Або: екскурсія на човні від Marina Grande", "Or: boat tour from Marina Grande", "Oppure: giro in barca da Marina Grande", "Ou : excursion en bateau depuis Marina Grande", "Oder: Bootstour ab Marina Grande"],
        // Описи місць
        "s.piazzetta": ["Центральна площа Капрі з годинниковою вежею та кав’ярнями.", "Capri’s main square, with clock tower and cafés.", "La piazza principale di Capri, con la torre dell’orologio e i caffè.", "La place principale de Capri, avec sa tour de l’horloge et ses cafés.", "Der Hauptplatz von Capri mit Uhrturm und Cafés."],
        "s.gardens":   ["Квіткові тераси з видом на Фарагіоні та Марина-Пікколу.", "Flower terraces with views of the Faraglioni and Marina Piccola.", "Terrazze fiorite con vista sui Faraglioni e su Marina Piccola.", "Terrasses fleuries avec vue sur les Faraglioni et Marina Piccola.", "Blumenterrassen mit Blick auf die Faraglioni und Marina Piccola."],
        "s.faraglioni":["Три скелі, символ острова, біля південного узбережжя.", "The three iconic sea stacks off the southern coast.", "I tre iconici scogli al largo della costa meridionale.", "Les trois rochers emblématiques au large de la côte sud.", "Die drei berühmten Felsen vor der Südküste."],
        "s.jovis":     ["Руїни величезної вілли імператора Тіберія на східному мисі.", "Ruins of Emperor Tiberius’s villa on the eastern headland.", "Rovine della villa dell’imperatore Tiberio sul promontorio orientale.", "Ruines de la villa de l’empereur Tibère sur le promontoire est.", "Ruinen der Villa von Kaiser Tiberius auf dem Ostkap."],
        "s.arco":      ["Природна кам’яна арка над морем.", "Natural limestone arch above the sea.", "Arco naturale in calcare a picco sul mare.", "Arche naturelle en calcaire au-dessus de la mer.", "Natürlicher Kalksteinbogen über dem Meer."],
        "s.solaro":    ["Найвища точка острова (589 м), підйом канатною дорогою.", "The island’s highest point (589 m), reached by chairlift.", "Il punto più alto dell’isola (589 m), si sale in seggiovia.", "Le point culminant de l’île (589 m), accessible en télésiège.", "Höchster Punkt der Insel (589 m), per Sessellift erreichbar."],
        "s.sanmichele":["Вілла й сад Акселя Мунте в Анакапрі.", "Axel Munthe’s villa and garden in Anacapri.", "Villa e giardino di Axel Munthe ad Anacapri.", "Villa et jardin d’Axel Munthe à Anacapri.", "Axel Munthes Villa mit Garten in Anacapri."],
        "s.grotta":    ["Морська печера з небесно-блакитною водою, заходять на малих човнах.", "Sea cave with glowing blue water, entered by small rowing boats.", "Grotta marina dall’acqua azzurra, si entra con piccole barche a remi.", "Grotte marine à l’eau bleue lumineuse, accessible en petites barques.", "Meereshöhle mit leuchtend blauem Wasser, Zugang per Ruderboot."],
        "s.faro":      ["Маяк на південно-західному мисі, популярний на заході сонця.", "Lighthouse on the south-western cape, popular at sunset.", "Faro sul promontorio sud-occidentale, molto frequentato al tramonto.", "Phare du cap sud-ouest, prisé au coucher du soleil.", "Leuchtturm am Südwestkap, beliebt bei Sonnenuntergang."],
        "s.marina-piccola": ["Маленький пляж і бухта на південному схилі біля Фарагіоні.", "Small beach and bay on the southern slope near the Faraglioni.", "Piccola spiaggia e baia sul versante sud vicino ai Faraglioni.", "Petite plage et baie sur le versant sud, près des Faraglioni.", "Kleiner Strand und Bucht am Südhang nahe den Faraglioni."],
        "s.da-paolino": ["Відомий ресторан під лимонними деревами в Анакапрі — бронювання заздалегідь.", "Famous lemon-grove restaurant in Anacapri — book ahead.", "Rinomato ristorante tra i limoni ad Anacapri: prenota in anticipo.", "Célèbre restaurant parmi les citronniers à Anacapri — réservez à l’avance.", "Bekanntes Restaurant im Zitronenhain in Anacapri — reservieren empfohlen."],
        "s.lo-smeraldo": ["Ресторан з терасою над скелями Капрі (демо-опис).", "Cliff-side terrace restaurant in Capri (demo description).", "Ristorante con terrazza sulle scogliere di Capri (descrizione dimostrativa).", "Restaurant en terrasse sur les falaises de Capri (description démo).", "Restaurant mit Terrasse über den Klippen von Capri (Demo-Beschreibung)."],
        "s.pescheria": ["Рибний дім і тратторія в центрі Капрі (демо-опис).", "Fish house and trattoria in central Capri (demo).", "Pescheria e trattoria nel centro di Capri (demo).", "Poissonnerie et trattoria au centre de Capri (démo).", "Fischladen und Trattoria in Capris Zentrum (Demo)."],
        "s.da-gemma": ["Класичний капріський ресторан на Via Vittorio Emanuele — мінестроне, макарони й морепродукти.", "Classic Capri town restaurant on Via Vittorio Emanuele — minestrone, pasta and seafood.", "Ristorante storico nel centro di Capri: minestrone, pasta e pesce.", "Restaurant classique de Capri sur la Via Vittorio Emanuele — minestrone, pâtes et fruits de mer.", "Klassisches Restaurant in Capri an der Via Vittorio Emanuele — Minestrone, Pasta, Meeresfrüchte."],
        "s.capannina": ["Один із найдавніших ресторанів острова (з 1939 р.) у історичному центрі.", "One of the island’s oldest restaurants (since 1939) in the historic centre.", "Tra i ristoranti più storici dell’isola (dal 1939), in centro.", "L’un des plus anciens restaurants de l’île (depuis 1939), en centre-ville.", "Eines der ältesten Restaurants der Insel (seit 1939) im historischen Zentrum."],
        "s.aurora": ["Знаменита піцца й неаполітанська кухня в центрі Capri (Via Fuorlovado).", "Famous pizza and Neapolitan cooking in central Capri (Via Fuorlovado).", "Pizza e cucina napoletana celebri nel centro di Capri.", "Pizza et cuisine napolitaine réputées au centre de Capri.", "Berühmte Pizza und neapolitanische Küche in Capris Zentrum."],
        "s.riccio": ["Пляжний клуб і ресторан над бухтою — морепродукти, літній дрес-код.", "Beach club restaurant over the cove — seafood, summer dress code.", "Beach club e ristorante sulla cala: pesce, abbigliamento estivo.", "Club de plage au-dessus de la crique — poisson, tenue estivale.", "Beach-Club-Restaurant über der Bucht — Fisch, Sommerdresscode."],
        "s.da-giorgio": ["Тратторія на східному узвитку з видом на затоку — добра після прогулянки до Villa Jovis.", "Trattoria on the eastern slope with bay views — handy after Villa Jovis.", "Trattoria sul versante est con vista sul golfo, ideale dopo Villa Jovis.", "Trattoria sur le versant est avec vue sur la baie, proche de Villa Jovis.", "Trattoria am Osthang mit Buchtblick — gut nach Villa Jovis."],
        "s.l-orchidea": ["Затишний ресторан біля П'яцетти — італійська класика й островна риба.", "Cosy spot near the Piazzetta — Italian classics and local fish.", "Locale accogliente vicino alla Piazzetta: classici italiani e pesce.", "Adresse conviviale près de la Piazzetta — classiques italiens et poisson local.", "Gemütliches Lokal nahe der Piazzetta — italienische Klassiker und Fisch."],
    ]
}
