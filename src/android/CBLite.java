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
import com.couchbase.lite.replicator.Replication;
import com.couchbase.lite.View;
import com.couchbase.lite.javascript.JavaScriptReplicationFilterCompiler;
import com.couchbase.lite.javascript.JavaScriptViewCompiler;

import java.io.FileInputStream;
import java.io.IOException;
import java.net.URL;
import java.util.HashMap;

public class CBLite extends CordovaPlugin {

    private static Manager dbmgr = null;
    private static HashMap<String, com.couchbase.lite.Database> activeDbs = null;

    public CBLite() {
        super();
        System.out.println("CBLite() constructor called");
    }

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        System.out.println("initialize() called");
        super.initialize(cordova, webView);
        try {
            View.setCompiler(new JavaScriptViewCompiler());
            Database.setFilterCompiler(new JavaScriptReplicationFilterCompiler());
            dbmgr = startCBLite(this.cordova.getActivity());
        } catch (final Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onReset() {
        //cancel change listeners
        if (activeDbs != null) activeDbs.clear();
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callback) {

        //UTIL
        if (action.equals("changes")) changes(args, callback);
        else if (action.equals("compact")) compact(args, callback);
        else if (action.equals("info")) info(args, callback);
        else if (action.equals("initDb")) initDb(args, callback);
        else if (action.equals("replicateFrom")) replicateFrom(args, callback);
        else if (action.equals("replicateTo")) replicateTo(args, callback);
        else if (action.equals("reset")) reset(args, callback);
        else if (action.equals("stopReplication")) stopReplication(args, callback);
        else if (action.equals("sync")) sync(args, callback);

            //READ
        else if (action.equals("allDocs")) allDocs(args, callback);
        else if (action.equals("get")) get(args, callback);

            //WRITE
        else if (action.equals("putAttachment")) putAttachment(args, callback);
        else if (action.equals("upsert")) upsert(args, callback);

        return true;
    }

    private void changes(JSONArray args, CallbackContext callback) {
    }

    private void compact(JSONArray args, CallbackContext callback) {
        try {
            String dbName = args.getString(0);
            activeDbs.get(dbName).compact();
            callback.success("attachment saved!");
        } catch (final Exception e) {
            e.printStackTrace();
            callback.error(e.getMessage());
        }
    }

    private void info(JSONArray args, CallbackContext callback) {
    }

    private void initDb(JSONArray args, CallbackContext callback) {
        try {
            String dbName = args.getString(0);
            activeDbs.put(dbName, dbmgr.getDatabase(dbName));
            callback.success("success");
        } catch (final Exception e) {
            e.printStackTrace();
            callback.error(e.getMessage());
        }
    }

    private void replicateFrom(JSONArray args, CallbackContext callback) {
    }

    private void replicateTo(JSONArray args, CallbackContext callback) {
    }

    private void reset(JSONArray args, CallbackContext callback) {
        this.onReset();
    }

    private void stopReplication(JSONArray args, CallbackContext callback) {
        try {
            String dbName = args.getString(0);
            Database db = activeDbs.get(dbName);
            if (db != null) {
                for (Replication replication : db.getAllReplications()) replication.stop();
                callback.success("true");
            } else callback.error("false");
        } catch (final Exception e) {
            e.printStackTrace();
            callback.error(e.getMessage());
        }
    }

    private void sync(JSONArray args, CallbackContext callback) {
        try {
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
        } catch (Exception e) {
            e.printStackTrace();
            callback.error(e.getMessage());
        }
    }


    private void allDocs(JSONArray args, CallbackContext callback) {
    }

    private void get(JSONArray args, CallbackContext callback) {
    }

    private void putAttachment(JSONArray args, CallbackContext callback) {
        try {
            String dbName = args.getString(0);
            String filePath = this.cordova.getActivity().getApplicationContext().getFilesDir() + "/" + args.getString(5) + "/" + args.getString(2);
            FileInputStream stream = new FileInputStream(filePath);
            Document doc = activeDbs.get(dbName).getDocument(args.getString(1));
            UnsavedRevision newRev = doc.getCurrentRevision().createRevision();
            newRev.setAttachment(args.getString(3), args.getString(4), stream);
            newRev.save();
            callback.success("attachment saved!");
        } catch (final Exception e) {
            e.printStackTrace();
            callback.error(e.getMessage());
        }
    }

    private void upsert(JSONArray args, CallbackContext callback) {
    }


    //PLUGIN BOILER PLATE

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

    @Override
    public void onResume(boolean multitasking) {
        System.out.println("CBLite.onResume() called");
    }

    @Override
    public void onPause(boolean multitasking) {
        System.out.println("CBLite.onPause() called");
    }
}
