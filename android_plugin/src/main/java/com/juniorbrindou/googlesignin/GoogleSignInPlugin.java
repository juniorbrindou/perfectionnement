package com.juniorbrindou.googlesignin;

import android.app.Activity;
import android.os.CancellationSignal;

import androidx.annotation.NonNull;
import androidx.credentials.ClearCredentialStateRequest;
import androidx.credentials.Credential;
import androidx.credentials.CredentialManager;
import androidx.credentials.CredentialManagerCallback;
import androidx.credentials.CustomCredential;
import androidx.credentials.GetCredentialRequest;
import androidx.credentials.GetCredentialResponse;
import androidx.credentials.exceptions.ClearCredentialException;
import androidx.credentials.exceptions.GetCredentialCancellationException;
import androidx.credentials.exceptions.GetCredentialException;

import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption;
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

/**
 * Connexion « Se connecter avec Google » par le Credential Manager d'Android.
 * Le jeu reçoit un jeton d'identité Google, qu'il transmet à Nakama
 * (link_google_async ou authenticate_google_async) ; le serveur le vérifie.
 */
public class GoogleSignInPlugin extends GodotPlugin {
    private final Executor executor = Executors.newSingleThreadExecutor();

    public GoogleSignInPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "GoogleSignIn";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        // Jeton d'identité, adresse e-mail, nom affiché.
        signals.add(new SignalInfo("sign_in_succeeded", String.class, String.class, String.class));
        // Code ("annule" ou "erreur") et message.
        signals.add(new SignalInfo("sign_in_failed", String.class, String.class));
        return signals;
    }

    /** Ouvre le choix du compte Google. serverClientId : identifiant OAuth « Application Web ». */
    @UsedByGodot
    public void signIn(String serverClientId) {
        Activity activity = getActivity();
        if (activity == null) {
            emitSignal("sign_in_failed", "erreur", "Activité Android indisponible.");
            return;
        }
        GetSignInWithGoogleOption option = new GetSignInWithGoogleOption.Builder(serverClientId).build();
        GetCredentialRequest request = new GetCredentialRequest.Builder().addCredentialOption(option).build();
        CredentialManager manager = CredentialManager.create(activity);
        manager.getCredentialAsync(activity, request, new CancellationSignal(), executor,
                new CredentialManagerCallback<GetCredentialResponse, GetCredentialException>() {
                    @Override
                    public void onResult(GetCredentialResponse response) {
                        Credential credential = response.getCredential();
                        if (credential instanceof CustomCredential
                                && GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL.equals(credential.getType())) {
                            try {
                                GoogleIdTokenCredential google = GoogleIdTokenCredential.createFrom(credential.getData());
                                String name = google.getDisplayName() != null ? google.getDisplayName() : "";
                                emitSignal("sign_in_succeeded", google.getIdToken(), google.getId(), name);
                            } catch (Exception e) {
                                emitSignal("sign_in_failed", "erreur", "Réponse Google illisible : " + e.getMessage());
                            }
                        } else {
                            emitSignal("sign_in_failed", "erreur", "Type d'identifiant inattendu.");
                        }
                    }

                    @Override
                    public void onError(@NonNull GetCredentialException e) {
                        String code = e instanceof GetCredentialCancellationException ? "annule" : "erreur";
                        emitSignal("sign_in_failed", code, e.getType() + " : " + e.getMessage());
                    }
                });
    }

    /** Oublie le compte choisi : la prochaine connexion redemandera lequel utiliser. */
    @UsedByGodot
    public void signOut() {
        Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        CredentialManager.create(activity).clearCredentialStateAsync(new ClearCredentialStateRequest(),
                new CancellationSignal(), executor,
                new CredentialManagerCallback<Void, ClearCredentialException>() {
                    @Override
                    public void onResult(Void result) {
                    }

                    @Override
                    public void onError(@NonNull ClearCredentialException e) {
                    }
                });
    }
}
