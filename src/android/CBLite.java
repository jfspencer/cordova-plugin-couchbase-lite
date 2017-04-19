package com.couchbase.cblite.phonegap;

import android.content.Context;
import android.text.TextUtils;

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
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

public class CBLite extends CordovaPlugin {

    private static Manager dbmgr = null;
    private static HashMap<String, Database> dbs = null;
    private static HashMap<String, Replication> replications = null;
    private static HashMap<String, Database.ChangeListener> changeListeners = null;
    private static HashMap<String, Replication.ChangeListener> replicationListeners = null;

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
        if(changeListeners != null){
            for (String dbName : changeListeners.keySet()) {
                for (Database.ChangeListener listener : changeListeners.values()) {
                    dbs.get(dbName).removeChangeListener(listener);
                }
            }
        }

        if(replicationListeners != null){
            for (String dbName : replicationListeners.keySet()) {
                for (Replication.ChangeListener listener : replicationListeners.values()) {
                    replications.get(dbName).removeChangeListener(listener);
                }
            }
        }


        //cancel replications
        if(replications != null){
            for (Replication replication : replications.values()) {
                replication.stop();
            }
        }

        if (dbs != null) dbs.clear();
        if (changeListeners != null) changeListeners.clear();
        if (replicationListeners != null) replicationListeners.clear();
        if (replications != null) replications.clear();
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callback) {

        //UTIL
        if (action.equals("changesDatabase")) changesDatabase(args, callback);
        else if (action.equals("changesReplication")) changesReplication(args, callback);
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

    private void changesDatabase(JSONArray args, final CallbackContext callback) {
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
                            callback.sendPluginResult(result);
                        }
                    }
                });

                dbs.get(dbName).addChangeListener(changeListeners.get(dbName));
            }

        } catch (final Exception e) {
            callback.error(e.getMessage());
        }
    }

    private void changesReplication(JSONArray args, final CallbackContext callback) {
        try {
            String dbName = args.getString(0);
            if (replicationListeners == null) {
                replicationListeners = new HashMap<String, Replication.ChangeListener>();
            }
            if (dbs.get(dbName) != null) {
                replicationListeners.put(dbName, new Replication.ChangeListener() {
                    public void changed(Replication.ChangeEvent event) {
                        Replication.ReplicationStatus status = event.getStatus();
                        PluginResult result = new PluginResult(PluginResult.Status.OK, status.toString());
                        result.setKeepCallback(true);
                        callback.sendPluginResult(result);
                    }
                });
                replications.get(dbName).addChangeListener(replicationListeners.get(dbName));
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


    private void allDocs(final JSONArray args, final CallbackContext callback) {
        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
        result.setKeepCallback(true);
        callback.sendPluginResult(result);

        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try{
                    String dbName = args.getString(0);
                    Query query = dbs.get(dbName).createAllDocumentsQuery();
                    query.setAllDocsMode(Query.AllDocsMode.ALL_DOCS);
                    query.shouldPrefetch();
                    query.isInclusiveEnd();
                    QueryEnumerator allDocsQuery = query.run();
                    ObjectMapper mapper = new ObjectMapper();
                    int batch = 1000;
                    final ArrayList<String> responseBuffer = new ArrayList<String>();
                    for (Iterator<QueryRow> it = allDocsQuery; it.hasNext(); ) {
                        QueryRow row = it.next();
                        responseBuffer.add(mapper.writeValueAsString(row.asJSONDictionary()));
                        if(responseBuffer.size() > batch){
                            List<String> buffer = responseBuffer.subList(0,batch);
                            responseBuffer.removeAll(buffer);
                            PluginResult result = new PluginResult(PluginResult.Status.OK, "[" + TextUtils.join(",",buffer) + "]");
                            result.setKeepCallback(true);
                            callback.sendPluginResult(result);
                        }
                    }

                    //send last batch
                    PluginResult result = new PluginResult(PluginResult.Status.OK, "[" + TextUtils.join(",",responseBuffer) + "]");
                    result.setKeepCallback(true);
                    callback.sendPluginResult(result);

                    //close callback
                    PluginResult finalResult = new PluginResult(PluginResult.Status.OK, "");
                    finalResult.setKeepCallback(false);
                    callback.sendPluginResult(finalResult);
                }
                catch(Exception e){
                    callback.error(e.getMessage());
                }
            }
        });
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
            dbmgr = new Manager(new AndroidContext(context), Manager.DEFAULT_OPTIONS);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return dbmgr;
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