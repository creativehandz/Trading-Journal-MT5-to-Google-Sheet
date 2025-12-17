# Trading Journal MT5 to Google Sheets

## 📞 Contact Information
### **Mobile:** 8559034400
### **Email:** prasharpranav@gmail.com

---

Automatically log all your MT5 trades to Google Sheets with this Expert Advisor (EA). Captures complete trade information including entry/exit prices, profit/loss, broker details, and account information.

## Features

- ✅ **Complete Trade Data**: Entry price, exit price, lots, SL, TP, profit/loss
- ✅ **Broker Information**: Broker name, account name, account number
- ✅ **TickMill Compatible**: Special handling for TickMill's deal history structure
- ✅ **Real-time Logging**: Trades automatically sent to Google Sheets when closed
- ✅ **Error Handling**: Robust fallback methods for data retrieval
- ✅ **JSON API**: Clean data structure sent via WebRequest

## Setup Instructions

### Part 1: Google Sheets Setup

#### Step 1: Create Google Sheet
1. Go to [Google Sheets](https://sheets.google.com)
2. Create a new spreadsheet
3. Name it "Trading Journal" or any name you prefer
4. Copy the spreadsheet ID from the URL:
   ```
   https://docs.google.com/spreadsheets/d/[SPREADSHEET_ID]/edit
   ```

#### Step 2: Setup Google Apps Script
1. In your Google Sheet, go to `Extensions` → `Apps Script`
2. Delete the default `myFunction()` code
3. Paste the code from `code.gs` file in this repository
4. **Important**: Replace the spreadsheet ID in line 9-11:
   ```javascript
   const ss = SpreadsheetApp.openById(
     "YOUR_SPREADSHEET_ID_HERE"  // Replace with your actual ID
   );
   ```

#### Step 3: Deploy Web App
1. Click `Deploy` → `New deployment`
2. Choose type: `Web app`
3. Set these settings:
   - **Execute as**: Me
   - **Who has access**: Anyone
4. Click `Deploy`
5. **Copy the Web App URL** - you'll need this for MT5

#### Step 4: Authorize Permissions
1. Click `Authorize access`
2. Choose your Google account
3. Click `Advanced` → `Go to [project name] (unsafe)`
4. Click `Allow`

### Part 2: MT5 Expert Advisor Setup

#### Step 1: Install EA File
1. Download `tradingjournal.mq5` from this repository
2. Copy the file to your MT5 data folder:
   ```
   MT5_Installation_Directory/MQL5/Experts/
   ```
   Or use MT5: `File` → `Open Data Folder` → `MQL5` → `Experts`

#### Step 2: Configure WebRequest URL
1. Open `tradingjournal.mq5` in MetaEditor
2. Replace the URL in line 6 with your Google Apps Script Web App URL:
   ```mql5
   string url = "YOUR_GOOGLE_APPS_SCRIPT_WEB_APP_URL_HERE";
   ```

#### Step 3: Enable WebRequest in MT5
1. In MT5, go to `Tools` → `Options` → `Expert Advisors`
2. Check `Allow WebRequest for listed URL:`
3. Add your Google Apps Script URL to the list
4. Click `OK`

#### Step 4: Compile and Attach EA
1. In MetaEditor, press `F7` to compile the EA
2. Fix any errors if they appear
3. In MT5, drag the EA from `Navigator` → `Expert Advisors` to a chart
4. In the settings dialog:
   - **Allow live trading**: ✅ Checked
   - **Allow DLL imports**: ❌ Not needed
   - **Allow imports of external experts**: ❌ Not needed
5. Click `OK`

## Usage

### What Gets Logged
Each closed trade automatically logs:

| Column | Description | Example |
|--------|-------------|---------|
| Time Out | Trade close time | 2025.12.17 21:14:44 |
| Symbol | Trading instrument | XAUUSD |
| Type | BUY or SELL | SELL |
| Lots | Trade volume | 0.01 |
| Entry Price | Opening price | 4337.07 |
| SL | Stop Loss | 4337.50 |
| TP | Take Profit | 4336.55 |
| Exit Price | Closing price | 4337.50 |
| Profit | Profit/Loss in account currency | -0.73 |
| Broker | Broker company name | Tickmill EU Ltd |
| Account Name | Account holder name | John Doe |
| Account Number | MT5 login number | 12345678 |
| Position ID | Unique position identifier | 146333014 |

### Monitoring
- Check MT5 Expert tab for logging activity
- Look for "WebRequest SUCCESS" messages
- Verify data appears in your Google Sheet
- "CLOSED_TRADE_LOGGED" response means success

## Troubleshooting

### Common Issues

#### WebRequest Error 4014
```
ERROR 4014: WebRequest URLs not allowed
```
**Solution**: Add your Google Apps Script URL to MT5's allowed WebRequest URLs (Step 3 in MT5 setup)

#### No Data in Google Sheet
1. Check if EA is running (smiley face in top-right corner)
2. Verify Google Apps Script URL is correct in EA
3. Check Expert tab for error messages
4. Ensure Google Sheet ID is correct in Apps Script

#### Entry Price Showing 0.00
- This EA has special TickMill compatibility
- For other brokers, check Expert tab logs for entry deal detection
- The EA has multiple fallback methods for entry price detection

#### Google Apps Script Errors
1. Check if sheet name is "Sheet1" or update the script
2. Verify spreadsheet permissions
3. Re-deploy the web app if needed

### Debug Steps
1. **Test Google Apps Script**: Visit the Web App URL in browser - should show "Trading journal webhook (CLOSE only) is live."
2. **Check MT5 Logs**: Expert tab shows all EA activity and errors
3. **Verify JSON Data**: Look for "JSON to send:" in Expert logs
4. **Test with Demo Account**: Always test on demo before live trading

## Broker Compatibility

### Tested Brokers
- ✅ **TickMill**: Full compatibility with special entry price detection
- ✅ **Standard MT5**: Compatible with most standard MT5 brokers

### Special Features for TickMill
- Enhanced deal history analysis
- Multiple fallback methods for entry price detection
- Order history integration for accurate open prices

## Support

### Error Reporting
If you encounter issues:
1. Check Expert tab logs in MT5
2. Note any error messages
3. Verify your setup against this README
4. Create an issue in this GitHub repository with:
   - Your broker name
   - MT5 build number
   - Error messages from Expert tab
   - Screenshot of the issue

### Customization
The EA can be modified to:
- Add more data fields
- Change Google Sheet structure
- Support multiple sheets
- Add trade filtering logic

## License

This project is open source. Feel free to modify and distribute according to your needs.

## Version History

- **v1.0**: Initial release with basic trade logging
- **v1.1**: Added TickMill compatibility and broker information capture
- **v1.2**: Enhanced entry price detection with multiple fallback methods

---

**Disclaimer**: This EA is for educational and analysis purposes. Always test on demo accounts before using with real money. Trading involves risk of loss.