// Models/GIFGroup.swift — Étape C

import Foundation

struct GIFGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var gifIDs: [UUID]

    // MARK: – Étape C : plage horaire
    // nil sur l'un ou l'autre = pas de contrainte.
    // La plage peut traverser minuit (ex. 22:00 → 02:00).
    var scheduleStart: DateComponents?
    var scheduleEnd:   DateComponents?

    // MARK: – Étape C : ancrage écran par groupe
    // nil = pas d'ancrage groupe.
    // Quand non-nil, setGroupPinnedScreen() propage screenID à tous les membres.
    var pinnedScreenID: UInt32?

    init(name: String, gifIDs: [UUID] = []) {
        self.id             = UUID()
        self.name           = name
        self.gifIDs         = gifIDs
        self.scheduleStart  = nil
        self.scheduleEnd    = nil
        self.pinnedScreenID = nil
    }

    // MARK: – Codable (decodeIfPresent — compatible JSON existant sans ces clés)

    enum CodingKeys: String, CodingKey {
        case id, name, gifIDs
        case scheduleStart, scheduleEnd, pinnedScreenID
    }

    init(from decoder: Decoder) throws {
        let c           = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,   forKey: .id)
        name            = try c.decode(String.self, forKey: .name)
        gifIDs          = try c.decode([UUID].self, forKey: .gifIDs)
        scheduleStart   = try c.decodeIfPresent(DateComponents.self, forKey: .scheduleStart)
        scheduleEnd     = try c.decodeIfPresent(DateComponents.self, forKey: .scheduleEnd)
        pinnedScreenID  = try c.decodeIfPresent(UInt32.self,         forKey: .pinnedScreenID)
    }

    // MARK: – Schedule helper

    /// Retourne true si l'heure courante est dans [scheduleStart, scheduleEnd].
    /// Gère le passage minuit : si start > end (en minutes), la plage englobe minuit.
    /// Retourne toujours true si scheduleStart ou scheduleEnd est nil.
    func isCurrentlyInSchedule() -> Bool {
        guard
            let startH = scheduleStart?.hour,   let startM = scheduleStart?.minute,
            let endH   = scheduleEnd?.hour,     let endM   = scheduleEnd?.minute
        else { return true }

        let cal = Calendar.current
        let now = cal.dateComponents([.hour, .minute], from: Date())
        guard let nowH = now.hour, let nowM = now.minute else { return true }

        let nowTotal   = nowH    * 60 + nowM
        let startTotal = startH  * 60 + startM
        let endTotal   = endH    * 60 + endM

        if startTotal <= endTotal {
            // Plage dans la même journée : ex. 08:00 → 18:00
            return nowTotal >= startTotal && nowTotal <= endTotal
        } else {
            // Plage traverse minuit : ex. 22:00 → 02:00
            return nowTotal >= startTotal || nowTotal <= endTotal
        }
    }
}
