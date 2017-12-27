import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.net.URL;
import java.nio.charset.Charset;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class CryptoRateAPI {

	private static String readAll(Reader rd) throws IOException {
		StringBuilder sb = new StringBuilder();
		int cp;
		while ((cp = rd.read()) != -1) {
			sb.append((char) cp);
		}
		return sb.toString();
	}

	public static JSONObject readJsonFromUrl(String url) throws IOException, JSONException {
		InputStream is = new URL(url).openStream();
		try {
			BufferedReader rd = new BufferedReader(new InputStreamReader(is, Charset.forName("UTF-8")));
			String jsonText = readAll(rd);
			// JSONObject json = new JSONObject(jsonText);
			JSONObject json = null;
			JSONArray jsonArray = new JSONArray(jsonText);
			for (int i = 0; i < jsonArray.length(); i++) {
				if (jsonArray.get(i) instanceof JSONObject) {
					json = (JSONObject) jsonArray.get(i);
					// String finalValue = (String)jsnObj.get("id");
				}
			}
			return json;
		} finally {
			is.close();
		}
	}
	
	public static float getCurrencyRate(String currency) {
		JSONObject json = null;
		try {
			json = readJsonFromUrl("https://api.coinmarketcap.com/v1/ticker/"+ currency +"/");
		} catch (FileNotFoundException e) {
			System.out.println("\"" + e.getMessage() + "\"" + " not found. Please try again with correct URL");
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (JSONException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		
		try {
			return Float.parseFloat(json.get("price_usd").toString());
		} catch (NumberFormatException | JSONException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return 0;
	}

	public static void main(String[] args) throws IOException, JSONException {
		System.out.println(getCurrencyRate("ethlend"));
		
	}
}
