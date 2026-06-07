//
//  MarkdownEditorView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import SwiftUI

struct MarkdownEditorView: View {
  var body: some View {
    ContentUnavailableView(
      "Markdown Is Not Enabled",
      systemImage: "text.document",
      description: Text(
        "The storage and windowing model already reserves a markdown mode, "
          + "but the editor is intentionally deferred."
      )
    )
  }
}
