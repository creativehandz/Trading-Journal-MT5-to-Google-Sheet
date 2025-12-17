function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return ContentService
        .createTextOutput("NO_POST_DATA")
        .setMimeType(ContentService.MimeType.TEXT);
    }

    const ss = SpreadsheetApp.openById(
      "1DqREsfViY4g4T-16RcUpliHW1zoFxBASgawVj9nDbi4"
    );

    const sheet = ss.getSheetByName("Sheet1");
    if (!sheet) {
      throw new Error("Sheet1 not found. Check sheet name.");
    }

    // Create headers if empty
    if (sheet.getLastRow() === 0) {
      sheet.appendRow([        
        "Time Out",
        "Symbol",
        "Type",
        "Lots",
        "Entry Price",
        "SL",
        "TP",
        "Exit Price",
        "Profit",
        "Broker",
        "Account Name",
        "Account Number",
        "Position ID"
      ]);
    }

    const data = JSON.parse(e.postData.contents);

    // Append CLOSED trade (single row)
    sheet.appendRow([
  data.time_out || "",
  data.symbol || "",
  data.type || "",
  data.lots || "",
  data.entry_price || "",
  data.sl || "",
  data.tp || "",
  data.exit_price || "",
  data.profit || "",
  data.broker || "",
  data.account_name || "",
  data.account_number || "",
  data.position_id || ""
]);

    return ContentService
      .createTextOutput("CLOSED_TRADE_LOGGED")
      .setMimeType(ContentService.MimeType.TEXT);

  } catch (err) {
    return ContentService
      .createTextOutput("ERROR: " + err.message)
      .setMimeType(ContentService.MimeType.TEXT);
  }
}

function doGet() {
  return ContentService
    .createTextOutput("Trading journal webhook (CLOSE only) is live.")
    .setMimeType(ContentService.MimeType.TEXT);
}
