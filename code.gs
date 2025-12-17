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
        "Position ID",
        "Team",
        "Risk:Reward",
        "Result"
      ]);
    }

    const data = JSON.parse(e.postData.contents);

    // Determine team member based on lot size
    function getTeamMember(lots) {
      const lotSize = parseFloat(lots);
      if (lotSize === 0.02) return "Pranav";
      if (lotSize === 0.04) return "Amit";
      if (lotSize === 0.1) return "Prateek";
      if (lotSize === 0.03) return "Devinder";
      return ""; // Unknown lot size
    }

    // Calculate Risk:Reward ratio
    function calculateRiskReward(entryPrice, sl, tp, tradeType) {
      const entry = parseFloat(entryPrice);
      const stopLoss = parseFloat(sl);
      const takeProfit = parseFloat(tp);
      
      // Skip calculation if any required value is missing or zero
      if (!entry || !stopLoss || !takeProfit || entry === 0 || stopLoss === 0 || takeProfit === 0) {
        return "N/A";
      }
      
      let risk, reward;
      
      if (tradeType === "BUY") {
        // For BUY: Risk = Entry - SL, Reward = TP - Entry
        risk = entry - stopLoss;
        reward = takeProfit - entry;
      } else if (tradeType === "SELL") {
        // For SELL: Risk = SL - Entry, Reward = Entry - TP
        risk = stopLoss - entry;
        reward = entry - takeProfit;
      } else {
        return "N/A";
      }
      
      // Avoid division by zero and ensure positive values
      if (risk <= 0 || reward <= 0) {
        return "N/A";
      }
      
      const ratio = reward / risk;
      return "1:" + ratio.toFixed(2);
    }

    // Determine trade result based on profit
    function getTradeResult(profit) {
      const profitValue = parseFloat(profit);
      if (profitValue > 0) return "WIN";
      if (profitValue < 0) return "LOSS";
      return "BREAKEVEN"; // For exactly 0 profit
    }

    const teamMember = getTeamMember(data.lots);
    const riskReward = calculateRiskReward(data.entry_price, data.sl, data.tp, data.type);
    const tradeResult = getTradeResult(data.profit);

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
  data.position_id || "",
  teamMember,
  riskReward,
  tradeResult
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
