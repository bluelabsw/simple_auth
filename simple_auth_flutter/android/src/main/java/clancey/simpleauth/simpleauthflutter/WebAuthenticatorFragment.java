package clancey.simpleauth.simpleauthflutter;

import androidx.fragment.app.DialogFragment;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.URLUtil;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.util.HashMap;
import java.util.UUID;

public class WebAuthenticatorFragment extends DialogFragment {
    private static final String AUTHENTICATOR_KEY = "AUTHENTICATOR_KEY";

    WebView webview;
    public static String UserAgent = "";

    public static HashMap<String,WebAuthenticator> States = new HashMap<>();

    public static WebAuthenticatorFragment newInstance(WebAuthenticator authenticator) {
        String stateKey = UUID.randomUUID().toString();
        WebAuthenticatorFragment.States.put(stateKey, authenticator);
        WebAuthenticatorFragment fragment = new WebAuthenticatorFragment();
        Bundle bundle = new Bundle();
        bundle.putString(AUTHENTICATOR_KEY, stateKey);
        fragment.setArguments(bundle);

        return fragment;
    }

    WebAuthenticator authenticator;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setStyle(STYLE_NO_FRAME, androidx.appcompat.R.style.Theme_AppCompat_Light_Dialog);
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        authenticator = States.get(getArguments().getString(AUTHENTICATOR_KEY));

        webview = new WebView(getContext());

        authenticator.addListener(authenticator.new CompleteNotifier(){
            @Override
            public void onComplete() {
                webview.stopLoading();
                dismiss();
            }
        });

        WebSettings settings = webview.getSettings();
        CookieManager.getInstance().removeAllCookies(null);
        CookieManager.getInstance().flush();
        if(UserAgent != null && !UserAgent.isEmpty())
        {
            settings.setUserAgentString(UserAgent);
            settings.setLoadWithOverviewMode(true);
        }
        settings.setJavaScriptEnabled(true);
        webview.setWebViewClient(new Client(this));

        if(savedInstanceState != null)
        {
            webview.restoreState(savedInstanceState);
        }

        webview.loadUrl(authenticator.initialUrl);
        return webview;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        authenticator.cancel();
    }

    class Client extends WebViewClient
    {
        private WebAuthenticatorFragment activity;

        Client(WebAuthenticatorFragment activity)
        {
            this.activity = activity;
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            String url = request.getUrl().toString();
            if (!url.isEmpty()) {
                if (URLUtil.isNetworkUrl(url)) {
                    return false;
                } else if (url.startsWith(activity.authenticator.redirectUrl.toString())){
                    activity.authenticator.checkUrl(url,false);
                }
            }
            return true;
        }
    }
}
