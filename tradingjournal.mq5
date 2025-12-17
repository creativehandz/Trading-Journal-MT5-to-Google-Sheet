#property strict

// =====================
// GOOGLE APPS SCRIPT URL
// =====================
string url = "https://script.google.com/macros/s/AKfycbzD11CTWdY449MtbMAlM-hGx89q8uOYKx96IhLvJeBeyb-79S3SUgfYWEOZNYQ_KGeC/exec";

// =====================
// SEND JSON TO GOOGLE SHEET
// =====================
void SendToSheet(string json)
{
   Print("=== SENDING TO GOOGLE SHEETS ===");
   Print("JSON length: ", StringLen(json));
   Print("JSON content: ", json);
   
   uchar data[];
   int len = StringToCharArray(json, data, 0, StringLen(json));

   if(len <= 0)
   {
      Print("ERROR: JSON conversion failed. Length: ", len);
      return;
   }

   Print("JSON converted to bytes. Length: ", len);
   
   uchar result[];
   string result_headers;
   string headers = "Content-Type: application/json\r\n";
   string referer = "";

   Print("Sending WebRequest to URL: ", url);
   ResetLastError();
   int res = WebRequest(
      "POST",
      url,
      headers,
      referer,
      5000,
      data,
      len,
      result,
      result_headers
   );

   int error_code = GetLastError();
   Print("WebRequest completed. HTTP Code: ", res, " Error Code: ", error_code);
   
   if(res == -1)
   {
      Print("WebRequest FAILED. Error Code: ", error_code);
      Print("Common errors: 4014=URLs not allowed, 4060=HTTP error, 5203=Copy error");
      
      // Check if URLs are allowed
      if(error_code == 4014)
      {
         Print("ERROR 4014: WebRequest URLs not allowed. Check Tools->Options->Expert Advisors->Allow WebRequest for listed URL");
      }
   }
   else
   {
      string response = CharArrayToString(result);
      Print("WebRequest SUCCESS. HTTP Code: ", res);
      Print("Response headers: ", result_headers);
      Print("Response body: ", response);
   }
}

// =====================
// TRADE TRANSACTION HANDLER
// =====================
void OnTradeTransaction(
   const MqlTradeTransaction &trans,
   const MqlTradeRequest &request,
   const MqlTradeResult &result
)
{
   Print("=== OnTradeTransaction TRIGGERED ===");
   Print("Transaction type: ", trans.type, " (DEAL_ADD=", TRADE_TRANSACTION_DEAL_ADD, ")");
   
   // Load full history (CRITICAL) - Load last 30 days to ensure we get all deals
   datetime from_time = TimeCurrent() - (30 * 24 * 60 * 60); // 30 days ago
   HistorySelect(from_time, TimeCurrent());
   Print("History loaded from: ", TimeToString(from_time), " to: ", TimeToString(TimeCurrent()));

   // We care about DEAL ADD events (type 6) and HISTORY ADD events (type 9)
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD && trans.type != TRADE_TRANSACTION_HISTORY_ADD)
   {
      Print("Ignoring transaction type: ", trans.type);
      return;
   }

   if(!HistoryDealSelect(trans.deal))
   {
      Print("ERROR: Could not select deal: ", trans.deal);
      return;
   }

   long deal_entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   long deal_type = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   double deal_profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   
   Print("Deal entry type: ", deal_entry, " Deal type: ", deal_type, " Profit: ", deal_profit);
   Print("Constants - DEAL_ENTRY_OUT=", DEAL_ENTRY_OUT, " DEAL_ENTRY_IN=", DEAL_ENTRY_IN, " DEAL_ENTRY_INOUT=", DEAL_ENTRY_INOUT);
   
   // Check if this is a closing deal by looking at entry type OR if it has profit/loss
   bool is_closing_deal = (deal_entry == DEAL_ENTRY_OUT) || 
                         (deal_entry == DEAL_ENTRY_INOUT) || 
                         (deal_profit != 0.0);
   
   if(!is_closing_deal)
   {
      Print("Ignoring deal - not a closing deal");
      return;
   }
   
   Print("*** FOUND CLOSING DEAL - Processing ***");

   ulong position_id = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);

   // =====================
   // EXIT DATA (FROM CLOSE DEAL)
   // =====================
   string symbol     = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   double exit_price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double profit     = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   double sl         = HistoryDealGetDouble(trans.deal, DEAL_SL);
   double tp         = HistoryDealGetDouble(trans.deal, DEAL_TP);
   datetime time_out = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   
   // Get broker information
   string broker_name = AccountInfoString(ACCOUNT_COMPANY);
   string account_name = AccountInfoString(ACCOUNT_NAME);
   long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
   
   Print("Broker info - Company: ", broker_name, " Account: ", account_name, " Number: ", account_number);

   // =====================
   // TICKMILL DIRECT METHOD: Try to get position open price immediately
   // =====================
   double entry_price = 0.0;
   double lots = 0.0;
   long side = DEAL_TYPE_BUY;
   bool entry_found = false;
   
   Print("TICKMILL DIRECT: Attempting to get position open price for Position ID: ", position_id);
   
   // First try: Select position from history using HistorySelectByPosition
   if(HistorySelectByPosition(position_id))
   {
      Print("Successfully selected position history for Position ID: ", position_id);
      
      // Look for position orders to get open price
      int orders_total = HistoryOrdersTotal();
      Print("Orders in position history: ", orders_total);
      
      for(int order_idx = 0; order_idx < orders_total; order_idx++)
      {
         ulong order_ticket = HistoryOrderGetTicket(order_idx);
         if(HistoryOrderSelect(order_ticket))
         {
            ulong order_pos_id = HistoryOrderGetInteger(order_ticket, ORDER_POSITION_ID);
            if(order_pos_id == position_id)
            {
               long order_type = HistoryOrderGetInteger(order_ticket, ORDER_TYPE);
               double order_price = HistoryOrderGetDouble(order_ticket, ORDER_PRICE_OPEN);
               double order_volume = HistoryOrderGetDouble(order_ticket, ORDER_VOLUME_CURRENT);
               
               Print("Found order for position - Type: ", order_type, " Price: ", order_price, " Volume: ", order_volume);
               
               // Use first matching order as entry
               if(!entry_found && order_price > 0)
               {
                  entry_price = order_price;
                  lots = order_volume;
                  side = (order_type == ORDER_TYPE_BUY) ? DEAL_TYPE_BUY : DEAL_TYPE_SELL;
                  entry_found = true;
                  Print("*** TICKMILL ORDER ENTRY FOUND *** Price: ", entry_price, " Lots: ", lots, " Side: ", (side == DEAL_TYPE_BUY ? "BUY" : "SELL"));
                  break;
               }
            }
         }
      }
   }

   // =====================
   // FALLBACK: FIND ENTRY DEAL(S) — HEDGE SAFE
   // =====================
   
   Print("Starting search for entry deals for position ID: ", position_id);

   int total = HistoryDealsTotal();
   Print("TOTAL DEALS IN HISTORY = ", total);

   // Enhanced search - look for all deals with matching position ID
   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(!HistoryDealSelect(deal))
         continue;

      long d_pos   = HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      long d_entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      double d_vol = HistoryDealGetDouble(deal, DEAL_VOLUME);
      double d_prc = HistoryDealGetDouble(deal, DEAL_PRICE);
      long d_type = HistoryDealGetInteger(deal, DEAL_TYPE);

      Print(
         "CHECK DEAL:",
         " deal=", deal,
         " pos_id=", d_pos,
         " entry=", d_entry,
         " volume=", d_vol,
         " price=", d_prc,
         " type=", d_type
      );

      if(d_pos != position_id)
         continue;

      Print("*** MATCHING POSITION ID FOUND *** Deal: ", deal, " Entry: ", d_entry, " Price: ", d_prc, " Volume: ", d_vol);

      // Check all possible entry types and log them
      if(d_entry == DEAL_ENTRY_IN) // Should be 0
      {
         Print("MATCH! Found DEAL_ENTRY_IN - Entry type: ", d_entry, " Price: ", d_prc, " Volume: ", d_vol);
         
         if(!entry_found)
         {
            entry_price = d_prc;
            side = d_type;
            entry_found = true;
            Print("*** ENTRY FOUND *** Price: ", entry_price, " Type: ", d_type, " Side: ", (side == DEAL_TYPE_BUY ? "BUY" : "SELL"));
         }

         // SUM LOTS (HEDGE-SAFE) - only count if volume > 0
         if(d_vol > 0)
         {
            lots += d_vol;
            Print("Added volume: ", d_vol, " Total lots so far: ", lots);
         }
      }
      else if(d_entry == DEAL_ENTRY_OUT) // Should be 1
      {
         Print("Found DEAL_ENTRY_OUT (exit deal) - Entry type: ", d_entry, " Price: ", d_prc, " Volume: ", d_vol);
      }
      else if(d_entry == DEAL_ENTRY_INOUT) // Should be 2  
      {
         Print("Found DEAL_ENTRY_INOUT - Entry type: ", d_entry, " Price: ", d_prc, " Volume: ", d_vol);
         
         if(!entry_found)
         {
            entry_price = d_prc;
            side = d_type;
            entry_found = true;
            Print("*** ENTRY FOUND FROM INOUT *** Price: ", entry_price, " Type: ", d_type, " Side: ", (side == DEAL_TYPE_BUY ? "BUY" : "SELL"));
         }

         if(d_vol > 0)
         {
            lots += d_vol;
            Print("Added volume from INOUT: ", d_vol, " Total lots so far: ", lots);
         }
      }
      else
      {
         Print("UNKNOWN ENTRY TYPE - Entry: ", d_entry, " Price: ", d_prc, " Volume: ", d_vol, " (This might be the entry we need!)");
         
         // Try to use this as entry if we haven't found one yet
         if(!entry_found)
         {
            entry_price = d_prc;
            side = d_type;
            entry_found = true;
            Print("*** USING UNKNOWN ENTRY TYPE *** Price: ", entry_price, " Type: ", d_type, " Side: ", (side == DEAL_TYPE_BUY ? "BUY" : "SELL"));
         }

         if(d_vol > 0)
         {
            lots += d_vol;
            Print("Added volume from unknown entry: ", d_vol, " Total lots so far: ", lots);
         }
      }
   }
   
   // TICKMILL FIX: Try to get entry price from position history first (most reliable)
   if(!entry_found)
   {
      Print("No entry deals found in history. Trying TickMill position history method...");
      
      // Method 1: Check if position is still active
      if(PositionSelectByTicket(position_id))
      {
         entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
         lots = PositionGetDouble(POSITION_VOLUME);
         side = PositionGetInteger(POSITION_TYPE);
         entry_found = true;
         Print("Found ACTIVE position - Entry Price (POSITION_PRICE_OPEN): ", entry_price, " Lots: ", lots);
      }
      else
      {
         Print("Position not active. Trying TickMill position history selection...");
         
         // Method 2: Try to select position from history by position ID
         if(HistorySelectByPosition(position_id))
         {
            Print("Selected position history for ID: ", position_id);
            
            // Get the first deal of this position (should be entry)
            int total_orders = HistoryOrdersTotal();
            Print("Total orders in position history: ", total_orders);
            
            for(int h = 0; h < total_orders; h++)
            {
               ulong order_ticket = HistoryOrderGetTicket(h);
               if(HistoryOrderSelect(order_ticket))
               {
                  if(HistoryOrderGetInteger(order_ticket, ORDER_POSITION_ID) == position_id)
                  {
                     entry_price = HistoryOrderGetDouble(order_ticket, ORDER_PRICE_OPEN);
                     lots = HistoryOrderGetDouble(order_ticket, ORDER_VOLUME_CURRENT);
                     side = HistoryOrderGetInteger(order_ticket, ORDER_TYPE);
                     
                     // Convert order type to deal type
                     if(side == ORDER_TYPE_BUY) side = DEAL_TYPE_BUY;
                     else if(side == ORDER_TYPE_SELL) side = DEAL_TYPE_SELL;
                     
                     entry_found = true;
                     Print("Found position from ORDER history - Entry Price: ", entry_price, " Lots: ", lots, " Side: ", (side == DEAL_TYPE_BUY ? "BUY" : "SELL"));
                     break;
                  }
               }
            }
         }
         
         // Method 3: Try selecting by symbol and checking all positions  
         if(!entry_found)
         {
            Print("Order history failed. Trying position selection by symbol...");
            string pos_symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
            for(int p = 0; p < PositionsTotal(); p++)
            {
               if(PositionSelectByTicket(PositionGetTicket(p)))
               {
                  if(PositionGetInteger(POSITION_IDENTIFIER) == position_id)
                  {
                     entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                     lots = PositionGetDouble(POSITION_VOLUME);
                     side = PositionGetInteger(POSITION_TYPE);
                     entry_found = true;
                     Print("Found position by identifier - Entry Price: ", entry_price, " Lots: ", lots);
                     break;
                  }
               }
            }
         }
      }
      
      // Extended deal search as last resort
      if(!entry_found)
      {
         Print("Position history failed, trying extended deal search...");
         datetime far_back = TimeCurrent() - (90 * 24 * 60 * 60); // 90 days ago
         HistorySelect(far_back, TimeCurrent());
         int new_total = HistoryDealsTotal();
         Print("Extended history loaded. New total deals: ", new_total);
         
         // Search all deals for this position ID
         for(int j = 0; j < new_total; j++)
         {
            ulong deal = HistoryDealGetTicket(j);
            if(!HistoryDealSelect(deal))
               continue;

            if(HistoryDealGetInteger(deal, DEAL_POSITION_ID) != position_id)
               continue;

            long d_entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
            double d_price = HistoryDealGetDouble(deal, DEAL_PRICE);
            double d_volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
            long d_type = HistoryDealGetInteger(deal, DEAL_TYPE);
            
            Print("Extended search - Deal: ", deal, " Entry: ", d_entry, " Price: ", d_price, " Vol: ", d_volume);
            
            if(d_entry == DEAL_ENTRY_IN || d_entry == DEAL_ENTRY_INOUT)
            {
               if(!entry_found)
               {
                  entry_price = d_price;
                  side = d_type;
                  entry_found = true;
                  Print("Found entry in extended search - Price: ", entry_price, " Type: ", d_type);
               }
               lots += d_volume;
            }
         }
      }
   }

   Print(
      "FINAL RESULT →",
      " ENTRY_PRICE=", entry_price,
      " LOTS=", lots,
      " SIDE=", (side == DEAL_TYPE_BUY ? "BUY" : "SELL"),
      " POSITION_ID=", position_id
   );

   // =====================
   // BUILD JSON (NO TIME IN)
   // =====================
   
   // Validate that we found entry data
   if(!entry_found || lots <= 0)
   {
      Print("WARNING: No complete entry data found. Using partial fallback.");
      
      // Use closing deal volume if no lots found
      if(lots <= 0)
      {
         lots = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
         Print("Trying closing deal volume: ", lots);
         
         // If closing deal volume is also 0, try to get from the deal we found in extended history
         if(lots <= 0)
         {
            Print("Closing deal volume is 0, searching extended history for ANY deal with this position ID...");
            for(int k = 0; k < HistoryDealsTotal(); k++)
            {
               ulong deal = HistoryDealGetTicket(k);
               if(!HistoryDealSelect(deal))
                  continue;
                  
               if(HistoryDealGetInteger(deal, DEAL_POSITION_ID) == position_id)
               {
                  double vol = HistoryDealGetDouble(deal, DEAL_VOLUME);
                  if(vol > 0)
                  {
                     lots = vol;
                     Print("Found volume from deal ", deal, ": ", lots);
                     break;
                  }
               }
            }
         }
         
         Print("Final volume after search: ", lots);
      }
      
      // TickMill-specific fix: Calculate entry price from profit since entry deals are not in history
      if(!entry_found)
      {
         Print("TICKMILL FIX: No entry deals found in history. Calculating entry price from profit/loss...");
         
         if(profit != 0.0 && lots > 0)
         {
            string symb = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
            double point = SymbolInfoDouble(symb, SYMBOL_POINT);
            
            Print("TickMill calculation - Symbol: ", symb, " Point: ", point, " Profit: ", profit, " Lots: ", lots);
            Print("Exit price: ", exit_price, " Deal type: ", deal_type, " (0=BUY, 1=SELL)");
            
            // For XAUUSD and similar symbols, calculate entry price from profit
            // Profit formula: (Exit Price - Entry Price) * Lots * Contract Size * Point Value
            // Simplified for XAUUSD: Profit = (Exit - Entry) * Lots * 100 (approximately)
            
            double price_difference = 0;
            
            // Calculate price difference based on profit
            if(lots > 0)
            {
               // For XAUUSD: typically 1 lot = $100 per point movement
               // So price_difference = profit / (lots * 100)
               price_difference = profit / (lots * 100.0);
            }
            
            Print("Calculated price difference: ", price_difference, " points");
            
            // Determine entry price based on deal type
            if(deal_type == DEAL_TYPE_SELL) // Closing SELL means original was BUY
            {
               // BUY lower, SELL higher = profit
               entry_price = exit_price - price_difference;
               side = DEAL_TYPE_BUY;
               Print("Original was BUY. Entry price = Exit price - Profit difference");
            }
            else // Closing BUY means original was SELL
            {
               // SELL higher, BUY lower = profit  
               entry_price = exit_price + price_difference;
               side = DEAL_TYPE_SELL;
               Print("Original was SELL. Entry price = Exit price + Profit difference");
            }
            
            entry_found = true;
            Print("*** TICKMILL CALCULATED ENTRY *** Price: ", entry_price, " Side: ", (side == DEAL_TYPE_BUY ? "BUY" : "SELL"));
         }
         else
         {
            Print("Cannot calculate entry price: profit=", profit, " lots=", lots);
            
            // Last resort: use a reasonable estimate
            if(deal_type == DEAL_TYPE_SELL) // Closing sell, assume small profit
            {
               entry_price = exit_price - 1.0; // Assume 1 point profit
               side = DEAL_TYPE_BUY;
            }
            else
            {
               entry_price = exit_price + 1.0; // Assume 1 point profit
               side = DEAL_TYPE_SELL;
            }
            entry_found = true;
            Print("*** USING ESTIMATED ENTRY *** Price: ", entry_price, " (±1 point estimate)");
         }
      }
      
      if(lots <= 0)
      {
         Print("WARNING: No volume data found. Using default 0.01 lots as last resort.");
         lots = 0.01; // Default minimum lot size as absolute fallback
      }
   }
   
   string json = "{";
   json += "\"time_out\":\"" + TimeToString(time_out, TIME_DATE|TIME_SECONDS) + "\",";
   json += "\"symbol\":\"" + symbol + "\",";
   json += "\"type\":\"" + (side == DEAL_TYPE_BUY ? "BUY" : "SELL") + "\",";
   json += "\"lots\":\"" + DoubleToString(lots, 2) + "\",";  // Changed to string format
   json += "\"entry_price\":" + DoubleToString(entry_price, _Digits) + ",";
   json += "\"sl\":" + DoubleToString(sl, _Digits) + ",";
   json += "\"tp\":" + DoubleToString(tp, _Digits) + ",";
   json += "\"exit_price\":" + DoubleToString(exit_price, _Digits) + ",";
   json += "\"profit\":" + DoubleToString(profit, 2) + ",";
   json += "\"broker\":\"" + broker_name + "\",";
   json += "\"account_name\":\"" + account_name + "\",";
   json += "\"account_number\":\"" + (string)account_number + "\",";
   json += "\"position_id\":\"" + (string)position_id + "\"";
   json += "}";

   Print("JSON to send: ", json);
   Print("Trade CLOSED. Sending to Google Sheets. Position ID=", position_id);
   SendToSheet(json);
}
