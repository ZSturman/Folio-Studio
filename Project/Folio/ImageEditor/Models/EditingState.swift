//
//  EditingState.swift
//  ImageEditor
//

import Foundation

enum EditingMode {
    case none
    case crop
    case transform
}

struct EditingState {
    var mode: EditingMode = .none
    var isImageLoaded: Bool = false
    var canUndo: Bool = false
    var canRedo: Bool = false
    var isSaving: Bool = false
}
