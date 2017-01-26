package com.couchbase.cblite.phonegap;

import android.content.Context;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CordovaInterface;
import org.json.JSONArray;
import com.couchbase.lite.Document;
import com.couchbase.lite.UnsavedRevision;
import com.couchbase.lite.android.AndroidContext;
import com.couchbase.lite.Database;
import com.couchbase.lite.Manager;
import com.couchbase.lite.auth.Authenticator;
import com.couchbase.lite.auth.AuthenticatorFactory;
import com.couchbase.lite.listener.LiteListener;
import com.couchbase.lite.listener.Credentials;
import com.couchbase.lite.replicator.Replication;
import com.couchbase.lite.router.URLStreamHandlerFactory;
import com.couchbase.lite.View;
import com.couchbase.lite.javascript.JavaScriptReplicationFilterCompiler;
import com.couchbase.lite.javascript.JavaScriptViewCompiler;

import java.io.FileInputStream;
import java.io.IOException;
import java.net.URL;
import java.util.HashMap;

public class CBLite extends CordovaPlugin {

    private static final int DEFAULT_LISTEN_PORT = 5984;
    private boolean initFailed = false;
    private int listenPort;
    private Credentials allowedCredentials;
    private Manager dbmgr = null;
    private HashMap<String, com.couchbase.lite.Database>activeDbs = null;

    public CBLite() {
        super();
        System.out.println("CBLite() constructor called");
    }

    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        System.out.println("initialize() called");
        super.initialize(cordova, webView);
        initCBLite();
    }

    private void initCBLite() {
        try {

            allowedCredentials = new Credentials();

            URLStreamHandlerFactory.registerSelfIgnoreError();

            View.setCompiler(new JavaScriptViewCompiler());
            Database.setFilterCompiler(new JavaScriptReplicationFilterCompiler());

            dbmgr = startCBLite(this.cordova.getActivity());

            listenPort = startCBLListener(DEFAULT_LISTEN_PORT, dbmgr, allowedCredentials);

            System.out.println("initCBLite() completed successfully");


        } catch (final Exception e) {
            e.printStackTrace();
            initFailed = true;
        }
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callback) {
        //Old API
        if (action.equals("stopReplication")) stopReplication(args, callback);
        if (action.equals("isReplicating")) isReplicating(args, callback);
        if (action.equals("getURL")) getURUL(args, callback);
        if (action.equals("putAttachment")) putAttachment(args, callback);
        if(action.equals("dbSync")) dbSync(args, callback);

        //Complete API
        if (action.equals("activeTasks")) activeTasks(args, callback);
        if (action.equals("changes")) changes(args, callback);
        if (action.equals("compact")) compact(args, callback);
        if (action.equals("destroy")) destroy(args, callback);
        if (action.equals("info")) info(args, callback);
        if (action.equals("initDb")) initDb(args, callback);
        if (action.equals("replicateFrom")) replicateFrom(args, callback);
        if (action.equals("replicateTo")) replicateTo(args, callback);
        if (action.equals("reset")) reset(args, callback);
        if (action.equals("revsDiff")) revsDiff(args, callback);
        if (action.equals("sync")) sync(args, callback);
        if (action.equals("viewCleanup")) viewCleanup(args, callback);
        if (action.equals("allDocs")) allDocs(args, callback);
        if (action.equals("get")) get(args, callback);
        if (action.equals("getAttachment")) getAttachment(args, callback);
        if (action.equals("query")) query(args, callback);
        if (action.equals("bulkDocs")) bulkDocs(args, callback);
        if (action.equals("post")) post(args, callback);
        if (action.equals("put")) put(args, callback);
        if (action.equals("remove")) remove(args, callback);
        if (action.equals("removeAttachment")) removeAttachment(args, callback);
        if (action.equals("upsert")) upsert(args, callback);
        return true;
    }

    private void activeTasks(JSONArray args, CallbackContext callback) {}
    private void changes(JSONArray args, CallbackContext callback) {}
    private void compact(JSONArray args, CallbackContext callback) {}
    private void destroy(JSONArray args, CallbackContext callback) {}
    private void info(JSONArray args, CallbackContext callback) {}
    private void initDb(JSONArray args, CallbackContext callback) {}
    private void replicateFrom(JSONArray args, CallbackContext callback) {}
    private void replicateTo(JSONArray args, CallbackContext callback) {}
    private void reset(JSONArray args, CallbackContext callback) {}
    private void revsDiff(JSONArray args, CallbackContext callback) {}
    private void sync(JSONArray args, CallbackContext callback) {
        try{
            String dbName = args.getString(0);
            URL syncUrl = new URL(args.getString(1));
            String user = args.getString(2);
            String pass = args.getString(3);

            Replication push = activeDbs.get(dbName).createPushReplication(syncUrl);
            Replication pull = activeDbs.get(dbName).createPullReplication(syncUrl);
            Authenticator auth = AuthenticatorFactory.createBasicAuthenticator(user, pass);
            push.setAuthenticator(auth);
            pull.setAuthenticator(auth);
            push.start();
            pull.start();
            callback.success("true");
        }catch(Exception e){
            e.printStackTrace();
            callback.error(e.getMessage());
        }
    }
    private void viewCleanup(JSONArray args, CallbackContext callback) {}
    private void allDocs(JSONArray args, CallbackContext callback) {}
    private void get(JSONArray args, CallbackContext callback) {}
    private void getAttachment(JSONArray args, CallbackContext callback) {}
    private void query(JSONArray args, CallbackContext callback) {}
    private void bulkDocs(JSONArray args, CallbackContext callback) {}
    private void post(JSONArray args, CallbackContext callback) {}
    private void put(JSONArray args, CallbackContext callback) {}

    private void putAttachment(JSONArray args, CallbackContext callback) {
        try{
            String filePath = this.cordova.getActivity().getApplicationContext().getFilesDir() + "/media/" + args.getString(2);
            FileInputStream stream = new FileInputStream(filePath);

            Database db = getDB(args.getString(0), callback);

            Document doc = db.getDocument(args.getString(1));
            UnsavedRevision newRev = doc.getCurrentRevision().createRevision();
            newRev.setAttachment(args.getString(3), args.getString(4), stream);
            newRev.save();
            callback.success("attachment saved!");
        }
        catch (final Exception e) {
            e.printStackTrace();
            callback.error(e.getMessage());
        }
    }

    private void remove(JSONArray args, CallbackContext callback) {}
    private void removeAttachment(JSONArray args, CallbackContext callback) {}
    private void upsert(JSONArray args, CallbackContext callback) {}

    private void dbSync(JSONArray args, CallbackContext callback) {
        try{
            String dbName = args.getString(0);

            URL syncUrl = new URL(args.getString(1));
            String user = args.getString(2);
            String pass = args.getString(3);
            Database db = getDB(dbName, callback);

            Replication push = db.createPushReplication(syncUrl);
            Replication pull = db.createPullReplication(syncUrl);
            Authenticator auth = AuthenticatorFactory.createBasicAuthenticator(user, pass);
            push.setAuthenticator(auth);
            pull.setAuthenticator(auth);
            push.start();
            pull.start();
            callback.success("true");

        }catch(Exception e){
            e.printStackTrace();
            callback.error(e.getMessage());
        }
    }

    private boolean getURUL(JSONArray args, CallbackContext callback) {
        try {
            if (initFailed) {
                callback.error("Failed to initialize couchbase lite.  See console logs");
                return false;
            } else {

                String callbackRespone = String.format("http://%s:%s@localhost:%d/", allowedCredentials.getLogin(), allowedCredentials.getPassword(), listenPort);
                callback.success(callbackRespone);
                return true;
            }
        } catch (final Exception e) {
            e.printStackTrace();
            callback.error(e.getMessage());
            return false;
        }
    }

    private void isReplicating(JSONArray args, CallbackContext callback) {
        try {
            Database db = getDB(args.getString(0), callback);
            if (db != null) {
                if (db.getActiveReplications().size() > 0) callback.success("true");
                else callback.success("false");
            }
            else {
                System.out.println("could not stop replication, database does not exist");
                callback.error("false");
            }
        } catch (final Exception e) {
            System.out.println("could not stop replication");
            e.printStackTrace();
            callback.error(e.getMessage());
        }
    }

    private void stopReplication(JSONArray args, CallbackContext callback) {
        try {
            Database db = getDB(args.getString(0), callback);
            if (db != null) {
                for (Replication replication : db.getAllReplications()) {
                    replication.stop();
                }
                callback.success("true");
            } else {
                System.out.println("could not stop replication, database does not exist");
                callback.error("false");
            }
        } catch (final Exception e) {
            System.out.println("could not stop replication");
            e.printStackTrace();
            callback.error(e.getMessage());
        }
    }


    private Manager startCBLite(Context context) {
        Manager manager;
        try {
//            Manager.enableLogging(Log.TAG, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_SYNC, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_QUERY, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_VIEW, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_CHANGE_TRACKER, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_BLOB_STORE, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_DATABASE, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_LISTENER, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_MULTI_STREAM_WRITER, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_REMOTE_REQUEST, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_ROUTER, Log.VERBOSE);
            manager = new Manager(new AndroidContext(context), Manager.DEFAULT_OPTIONS);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return manager;
    }

    //DEPRECATED
    private Database getDB(String dbName, CallbackContext callback) {
        try {
            Database db = dbmgr.getExistingDatabase(dbName);

            if (db == null) return null;
            else return db;
        } catch (final Exception e) {
            System.out.println("could not stop replication");
            e.printStackTrace();
            callback.error(e.getMessage());
        }
        return null;
    }

    private int startCBLListener(int listenPort, Manager manager, Credentials allowedCredentials) {

        LiteListener listener = new LiteListener(manager, listenPort, allowedCredentials);
        int boundPort = listener.getListenPort();
        Thread thread = new Thread(listener);
        thread.start();
        return boundPort;
    }

    public void onResume(boolean multitasking) {
        System.out.println("CBLite.onResume() called");
    }

    public void onPause(boolean multitasking) {
        System.out.println("CBLite.onPause() called");
    }
}
