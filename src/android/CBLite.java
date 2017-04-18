package com.couchbase.cblite.phonegap;

import android.content.Context;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;

import com.couchbase.lite.Document;
import com.couchbase.lite.DocumentChange;
import com.couchbase.lite.Query;
import com.couchbase.lite.QueryEnumerator;
import com.couchbase.lite.QueryRow;
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
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.FileInputStream;
import java.io.IOException;
import java.net.URL;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

public class CBLite extends CordovaPlugin {

    private static Manager dbmgr = null;
    private static HashMap<String, Database> dbs = null;
    private static HashMap<String, Replication> replications = null;
    private static HashMap<String, Database.ChangeListener> changeListeners = null;

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
        for (String dbName : changeListeners.keySet()) {
            for (Database.ChangeListener listener : changeListeners.values()) {
                dbs.get(dbName).removeChangeListener(listener);
            }
        }

        //cancel replications
        for (Replication replication : replications.values()) {
            replication.stop();
        }

        if (!dbs.isEmpty()) dbs.clear();
        if (!changeListeners.isEmpty()) changeListeners.clear();
        if (!replications.isEmpty()) replications.clear();
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
        final CallbackContext innerCallback = callback;

        try {
            String dbName = args.getString(0);
            if (changeListeners == null) {
                changeListeners = new HashMap<String, Database.ChangeListener>();
            }
            if (dbs.get(dbName) != null) {
                changeListeners.put(dbName, new Database.ChangeListener() {
                    public void changed(Database.ChangeEvent event) {
                        List<DocumentChange> changes = event.getChanges();
                        for (DocumentChange change : changes) {
                            PluginResult result = new PluginResult(PluginResult.Status.OK, change.getDocumentId());
                            result.setKeepCallback(true);
                            innerCallback.sendPluginResult(result);
                        }
                    }
                });

                dbs.get(dbName).addChangeListener(changeListeners.get(dbName));
            }

        } catch (final Exception e) {
            callback.error(e.getMessage());
        }
    }

    private void compact(JSONArray args, CallbackContext callback) {
        try {
            String dbName = args.getString(0);
            dbs.get(dbName).compact();
            callback.success("attachment saved!");
        } catch (final Exception e) {
            callback.error(e.getMessage());
        }
    }

    private void info(JSONArray args, CallbackContext callback) {
        try {
            String dbName = args.getString(0);
            callback.success(dbs.get(dbName).getDocumentCount());
        } catch (final Exception e) {
            callback.error(e.getMessage());
        }
    }

    private void initDb(JSONArray args, CallbackContext callback) {
        try {
            String dbName = args.getString(0);
            if (dbs == null) dbs = new HashMap<String, Database>();
            dbs.put(dbName, dbmgr.getDatabase(dbName));
            callback.success("CBL db init success");
        } catch (final Exception e) {
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
            Database db = dbs.get(dbName);
            if (db != null) {
                for (Replication replication : db.getAllReplications()) replication.stop();
                callback.success("true");
            } else callback.error("false");
        } catch (final Exception e) {
            callback.error(e.getMessage());
        }
    }

    private void sync(JSONArray args, CallbackContext callback) {
        try {
            String dbName = args.getString(0);
            URL syncUrl = new URL(args.getString(1));
            String user = args.getString(2);
            String pass = args.getString(3);

            if(replications == null) replications = new HashMap<String, Replication>();

            Replication push = dbs.get(dbName).createPushReplication(syncUrl);
            Replication pull = dbs.get(dbName).createPullReplication(syncUrl);
            Authenticator auth = AuthenticatorFactory.createBasicAuthenticator(user, pass);
            push.setAuthenticator(auth);
            pull.setAuthenticator(auth);
            push.start();
            pull.start();

            replications.put(dbName + "_push",push);
            replications.put(dbName + "_pull", pull);

            callback.success("true");
        } catch (Exception e) {
            callback.error(e.getMessage());
        }
    }


    private void allDocs(JSONArray args, CallbackContext callback) {
        try{
            String dbName = args.getString(0);
            Query query = dbs.get(dbName).createAllDocumentsQuery();
            query.setAllDocsMode(Query.AllDocsMode.ALL_DOCS);
            query.shouldPrefetch();
            QueryEnumerator allDocsQuery = query.run();
            ObjectMapper mapper = new ObjectMapper();
            for (Iterator<QueryRow> it = allDocsQuery; it.hasNext(); ) {
                QueryRow row = it.next();
                String jsonString = mapper.writeValueAsString(row.asJSONDictionary());
                PluginResult result = new PluginResult(PluginResult.Status.OK, jsonString);
                result.setKeepCallback(true);
                callback.sendPluginResult(result);
            }
            PluginResult result = new PluginResult(PluginResult.Status.OK, "{}");
            result.setKeepCallback(false);
            callback.sendPluginResult(result);
        }
        catch(Exception e){
            callback.error(e.getMessage());
        }
    }

    private void get(JSONArray args, CallbackContext callback) {
        try{
            String dbName = args.getString(0);
            String id = args.getString(1);
            Document doc = dbs.get(dbName).getDocument(id);
            ObjectMapper mapper = new ObjectMapper();
            String jsonString = mapper.writeValueAsString(doc.getProperties());
            callback.success(jsonString);
        }
        catch(final Exception e){
            callback.error(e.getMessage());
        }
    }

    private void putAttachment(JSONArray args, CallbackContext callback) {
        try {
            String dbName = args.getString(0);
            String filePath = this.cordova.getActivity().getApplicationContext().getFilesDir() + "/" + args.getString(5) + "/" + args.getString(2);
            FileInputStream stream = new FileInputStream(filePath);
            Document doc = dbs.get(dbName).getDocument(args.getString(1));
            UnsavedRevision newRev = doc.getCurrentRevision().createRevision();
            newRev.setAttachment(args.getString(3), args.getString(4), stream);
            newRev.save();
            callback.success("attachment saved!");
        } catch (final Exception e) {
            callback.error(e.getMessage());
        }
    }

    private void upsert(JSONArray args, CallbackContext callback) {
        try{
            String dbName = args.getString(0);
            String id = args.getString(1);
            String jsonString = args.getString(2);

            ObjectMapper mapper = new ObjectMapper();

            Document doc = dbs.get(dbName).getExistingDocument(id);
            Map<String, Object> mapDoc = mapper.readValue(jsonString, new TypeReference<Map<String, Object>>() {});
            if(doc != null) doc.putProperties(mapDoc);
            else{
                Document newDoc = dbs.get(dbName).getDocument(id);
                newDoc.putProperties(mapDoc);
            }
            callback.success("upsert successful");
        }
        catch(final Exception e){
            callback.error(e.getMessage());
        }
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