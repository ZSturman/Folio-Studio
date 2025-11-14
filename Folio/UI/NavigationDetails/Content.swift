////
////  Content.swift
////  Folio
////
////  Created by Zachary Sturman on 11/2/25.
////
//
//
//import Foundation
//import SwiftUI
//
//
//struct ContentTabView: View {
//    @Binding var document: FolioDocument
//    
//    @State private var errorMessage: String?
//    @State private var newCustomName: String = ""
//    
//    #warning("Fix the issue where when it's a custom image label the user is unable to change the aspect ratio. Also the preview window shows an aspect ration different than that of the image editor view")
//    
//
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//
//            
//            VStack(alignment: .leading, spacing: 12) {
//                
//                if let msg = errorMessage {
//                    Text(msg).foregroundColor(.red).font(.caption)
//                }
//                
//                VStack {
//                    ImageSlotView(
//                        label: .banner,
//                        jsonImage: Binding(
//                            get: { document.images[.banner] },
//                            set: { document.images[.banner] = $0 }
//                        ),
//                        document: $document
//                    )
//                   
//                    ImageSlotView(
//                        label: .heroBanner,
//                        jsonImage: Binding(
//                            get: { document.images[.heroBanner] },
//                            set: { document.images[.heroBanner] = $0 }
//                        ),
//                        document: $document
//                    )
//                   
//                    
//                    HStack {
//                        
//                        VStack {
//                            ImageSlotView(
//                                label: .thumbnail,
//                                jsonImage: Binding(
//                                    get: { document.images[.thumbnail] },
//                                    set: { document.images[.thumbnail] = $0 }
//                                ),
//                                document: $document
//                            )
//                           
//                            ImageSlotView(
//                                label: .icon,
//                                jsonImage: Binding(
//                                    get: { document.images[.icon] },
//                                    set: { document.images[.icon] = $0 }
//                                ),
//                                document: $document
//                            )
//                         
//                        }
//                        
//                        ImageSlotView(
//                            label: .poster,
//                            jsonImage: Binding(
//                                get: { document.images[.poster] },
//                                set: { document.images[.poster] = $0 }
//                            ),
//                            document: $document
//                        )
//                     
//                    }
//                }
//
//
//    
//
//
//                // Derive existing custom labels from the document.images keys
//                let customNames = document.images.keys.compactMap { key -> String? in
//                    key.hasPrefix("custom:") ? String(key.dropFirst(7)) : nil
//                }.sorted()
//
//                ForEach(customNames, id: \.self) { name in
//                    ImageSlotView(
//                        label: .custom(name),
//                        jsonImage: Binding(
//                            get: { document.images[.custom(name)] },
//                            set: { document.images[.custom(name)] = $0 }
//                        ),
//                        document: $document
//                    )
//                    .disabled(document.assetsFolder == nil)
//                    .overlay(alignment: .topTrailing) {
//                        if document.assetsFolder == nil {
//                            Text("Select edited folder first")
//                                .font(.caption2)
//                                .padding(4)
//                                .background(.yellow.opacity(0.3))
//                                .clipShape(RoundedRectangle(cornerRadius: 4))
//                                .padding(6)
//                        }
//                    }
//                    Divider()
//                }
//
//
//                HStack(spacing: 8) {
//                    TextField("Custom label name", text: $newCustomName)
//                        .textFieldStyle(RoundedBorderTextFieldStyle())
//                        .frame(maxWidth: 250)
//                    Button("Add Custom") {
//                        let trimmed = newCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
//                        guard !trimmed.isEmpty else { return }
//                        // If this custom label does not yet exist, create it like presets
//                        if document.images[.custom(trimmed)] == nil {
//                            document.images[.custom(trimmed)] = AssetPath(pathToOriginal: "", pathToEdited: "")
//                        }
//                        newCustomName = ""
//                    }
//                    Spacer()
//                }
//            }
//            .padding()
//        
//            
//            Spacer()
//        }
//        .padding()
//    }
//}
//
//#Preview {
//    ScrollView {
//        ContentTabView(document:
//                .constant(FolioDocument()))
//    }
//}
