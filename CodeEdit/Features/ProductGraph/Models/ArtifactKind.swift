//
//  ArtifactKind.swift
//  CodeEdit
//

import AppKit

/// Category groupings for the 23 artifact kinds (ADR-0001 §4).
enum ArtifactCategory: String, CaseIterable, Identifiable {
    case discovery
    case planning
    case evidence
    case gtm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .discovery: return "Discovery & Strategy"
        case .planning:  return "Definition & Planning"
        case .evidence:  return "Evidence & Learning"
        case .gtm:       return "Go-to-Market"
        }
    }

    /// Folder name under `product/` (matches ADR-0001 §4 layout).
    var folderName: String { rawValue }

    var systemImage: String {
        switch self {
        case .discovery: return "lightbulb"
        case .planning:  return "doc.text"
        case .evidence:  return "bubble.left"
        case .gtm:       return "megaphone"
        }
    }
}

/// All 23 typed artifact kinds from ADR-0001-schema.md.
enum ArtifactKind: String, CaseIterable, Identifiable {
    // Discovery & strategy
    case problem     = "problem"
    case persona     = "persona"
    case vpc         = "vpc"
    case bmc         = "bmc"
    case leanCanvas  = "lean-canvas"
    case journey     = "journey"
    case storyMap    = "story-map"
    case ost         = "ost"
    case competitor  = "competitor"
    case marketNote  = "market-note"
    // Definition & planning
    case prd         = "prd"
    case spec        = "spec"
    case adr         = "adr"
    case roadmapItem = "roadmap-item"
    case okr         = "okr"
    case experiment  = "experiment"
    // Evidence & learning
    case researchNote = "research-note"
    case interview    = "interview"
    case feedback     = "feedback"
    case insight      = "insight"
    case assumption   = "assumption"
    // Go-to-market
    case gtmBrief    = "gtm-brief"
    case landingPage = "landing-page"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .problem:      return "Problem"
        case .persona:      return "Persona"
        case .vpc:          return "Value Proposition Canvas"
        case .bmc:          return "Business Model Canvas"
        case .leanCanvas:   return "Lean Canvas"
        case .journey:      return "Customer Journey Map"
        case .storyMap:     return "User Story Map"
        case .ost:          return "Opportunity Solution Tree"
        case .competitor:   return "Competitor Card"
        case .marketNote:   return "Market Note"
        case .prd:          return "PRD"
        case .spec:         return "Spec"
        case .adr:          return "ADR"
        case .roadmapItem:  return "Roadmap Item"
        case .okr:          return "OKR / Metric"
        case .experiment:   return "Experiment"
        case .researchNote: return "Research Note"
        case .interview:    return "Customer Interview"
        case .feedback:     return "Feedback"
        case .insight:      return "Insight"
        case .assumption:   return "Assumption"
        case .gtmBrief:     return "GTM Brief"
        case .landingPage:  return "Landing Page Draft"
        }
    }

    /// Short abbreviation shown in compact navigator/quick-open badges.
    var shortName: String {
        switch self {
        case .problem:      return "PRB"
        case .persona:      return "PER"
        case .vpc:          return "VPC"
        case .bmc:          return "BMC"
        case .leanCanvas:   return "LC"
        case .journey:      return "JNY"
        case .storyMap:     return "MAP"
        case .ost:          return "OST"
        case .competitor:   return "CMP"
        case .marketNote:   return "MKT"
        case .prd:          return "PRD"
        case .spec:         return "SPEC"
        case .adr:          return "ADR"
        case .roadmapItem:  return "RMI"
        case .okr:          return "OKR"
        case .experiment:   return "EXP"
        case .researchNote: return "RSN"
        case .interview:    return "INT"
        case .feedback:     return "FBK"
        case .insight:      return "INS"
        case .assumption:   return "ASM"
        case .gtmBrief:     return "GTM"
        case .landingPage:  return "LPD"
        }
    }

    /// ID prefix per ADR-0001 §1.
    var idPrefix: String {
        switch self {
        case .problem:      return "prb"
        case .persona:      return "per"
        case .vpc:          return "vpc"
        case .bmc:          return "bmc"
        case .leanCanvas:   return "lean"
        case .journey:      return "jny"
        case .storyMap:     return "smap"
        case .ost:          return "ost"
        case .competitor:   return "cmp"
        case .marketNote:   return "mkt"
        case .prd:          return "prd"
        case .spec:         return "spec"
        case .adr:          return "adr"
        case .roadmapItem:  return "rmi"
        case .okr:          return "okr"
        case .experiment:   return "exp"
        case .researchNote: return "rsn"
        case .interview:    return "int"
        case .feedback:     return "fbk"
        case .insight:      return "ins"
        case .assumption:   return "asm"
        case .gtmBrief:     return "gtm"
        case .landingPage:  return "lpd"
        }
    }

    var category: ArtifactCategory {
        switch self {
        case .problem, .persona, .vpc, .bmc, .leanCanvas, .journey, .storyMap, .ost, .competitor, .marketNote:
            return .discovery
        case .prd, .spec, .adr, .roadmapItem, .okr, .experiment:
            return .planning
        case .researchNote, .interview, .feedback, .insight, .assumption:
            return .evidence
        case .gtmBrief, .landingPage:
            return .gtm
        }
    }

    var systemImage: String {
        switch self {
        case .problem:      return "exclamationmark.circle"
        case .persona:      return "person.circle"
        case .vpc:          return "square.grid.2x2"
        case .bmc:          return "rectangle.grid.3x2"
        case .leanCanvas:   return "rectangle.grid.2x2"
        case .journey:      return "arrow.right.circle"
        case .storyMap:     return "map"
        case .ost:          return "tree"
        case .competitor:   return "chart.bar.xaxis"
        case .marketNote:   return "note.text"
        case .prd:          return "doc.richtext"
        case .spec:         return "gearshape.2"
        case .adr:          return "checkmark.seal"
        case .roadmapItem:  return "flag"
        case .okr:          return "target"
        case .experiment:   return "flask"
        case .researchNote: return "magnifyingglass"
        case .interview:    return "mic"
        case .feedback:     return "bubble.left"
        case .insight:      return "lightbulb"
        case .assumption:   return "questionmark.circle"
        case .gtmBrief:     return "megaphone"
        case .landingPage:  return "globe"
        }
    }

    var templateName: String { rawValue }

    var statuses: [String] {
        switch self {
        case .assumption:  return ["untested", "validating", "validated", "falsified"]
        case .experiment:  return ["planned", "running", "concluded"]
        case .adr:         return ["proposed", "accepted", "superseded"]
        default:           return ["draft", "active", "superseded", "archived"]
        }
    }

    var defaultStatus: String {
        switch self {
        case .assumption:  return "untested"
        case .experiment:  return "planned"
        case .adr:         return "proposed"
        default:           return "draft"
        }
    }

    var categoryColor: NSColor {
        switch category {
        case .discovery: return .systemPurple
        case .planning:  return .systemBlue
        case .evidence:  return .systemGreen
        case .gtm:       return .systemOrange
        }
    }

    static func from(_ raw: String) -> ArtifactKind? {
        allCases.first { $0.rawValue == raw }
    }
}
