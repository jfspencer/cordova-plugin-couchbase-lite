package com.couchbase.cblite.phonegap;

import android.content.Context;
import android.database.sqlite.*;
import android.text.TextUtils;

import org.apache.commons.collections4.ListUtils;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;

import com.couchbase.lite.Attachment;
import com.couchbase.lite.DatabaseOptions;
import com.couchbase.lite.Document;
import com.couchbase.lite.DocumentChange;
import com.couchbase.lite.Emitter;
import com.couchbase.lite.Mapper;
import com.couchbase.lite.Query;
import com.couchbase.lite.QueryEnumerator;
import com.couchbase.lite.QueryRow;
import com.couchbase.lite.Revision;
import com.couchbase.lite.UnsavedRevision;
import com.couchbase.lite.android.AndroidContext;
import com.couchbase.lite.Database;
import com.couchbase.lite.Manager;
import com.couchbase.lite.auth.Authenticator;
import com.couchbase.lite.auth.AuthenticatorFactory;
import com.couchbase.lite.replicator.RemoteRequestResponseException;
import com.couchbase.lite.replicator.Replication;
import com.couchbase.lite.View;
import com.couchbase.lite.javascript.JavaScriptReplicationFilterCompiler;
import com.couchbase.lite.javascript.JavaScriptViewCompiler;
import com.couchbase.lite.util.Log;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;

import main.java.com.mindscapehq.android.raygun4android.RaygunClient;
import okhttp3.*;

public class CBLite extends CordovaPlugin {

    private static Manager dbmgr = null;
    private static HashMap<String, Database> dbs = null;
    private static HashMap<String, Replication> replications = null;
    private static HashMap<String, Database.ChangeListener> changeListeners = null;
    private static HashMap<String, Replication.ChangeListener> replicationListeners = null;
    private static ArrayList<CallbackContext> callbacks = null;
    private static int runnerCount = 0;
    final static int MAX_THREADS = 3;
    private static ObjectMapper mapper = new ObjectMapper();
    private static SQLiteDatabase callerIdDb;
    private static SQLiteStatement preparedInsert;

    public CBLite() {
        super();
    }

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        try {
            mapper.getFactory().configure(JsonGenerator.Feature.ESCAPE_NON_ASCII, true);
            View.setCompiler(new JavaScriptViewCompiler());
            Database.setFilterCompiler(new JavaScriptReplicationFilterCompiler());
            dbmgr = startCBLite(this.cordova.getActivity());

            dbs = new HashMap<String, Database>();
            replications = new HashMap<String, Replication>();
            changeListeners = new HashMap<String, Database.ChangeListener>();
            replicationListeners = new HashMap<String, Replication.ChangeListener>();
            callbacks = new ArrayList<CallbackContext>();
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

        for (String dbName : replicationListeners.keySet()) {
            for (Replication.ChangeListener listener : replicationListeners.values()) {
                try {
                    replications.get(dbName + "_push").removeChangeListener(listener);
                } catch (Exception e) {
                }
                try {
                    replications.get(dbName + "_pull").removeChangeListener(listener);
                } catch (Exception e) {
                }
            }
        }

        //cancel replications
        for (Replication replication : replications.values()) {
            replication.stop();
        }

        //cancel callbacks
        for (CallbackContext context : callbacks) {
            PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
            result.setKeepCallback(false);
            context.sendPluginResult(result);
        }

        dbs.clear();
        changeListeners.clear();
        replicationListeners.clear();
        replications.clear();
        callbacks.clear();
        runnerCount = 0;
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callback) {

        //UTIL
        if (action.equals("changesDatabase")) changesDatabase(args, callback);
        else if (action.equals("changesReplication")) changesReplication(args, callback);
        else if (action.equals("compact")) compact(args, callback);
        else if (action.equals("info")) info(args, callback);
        else if (action.equals("initCallerID")) initCallerID(args, callback);
        else if (action.equals("initDb")) initDb(args, callback);
        else if (action.equals("lastSequence")) lastSequence(args, callback);
        else if (action.equals("replicateFrom")) replicateFrom(args, callback);
        else if (action.equals("replicateTo")) replicateTo(args, callback);
        else if (action.equals("reset")) reset(args, callback);
        else if (action.equals("stopReplication")) stopReplication(args, callback);
        else if (action.equals("sync")) sync(args, callback);
        else if (action.equals("resetCallbacks")) resetCallbacks(args, callback);

        else if (action.equals("startPushReplication")) startPushReplication(args, callback);
        else if (action.equals("pushReplicationIsRunning"))
            pushReplicationIsRunning(args, callback);
        else if (action.equals("deleteUserDbs")) deleteUserDbs(args, callback);

            //READ
        else if (action.equals("buildViewDocs")) buildViewDocs(args, callback);
        else if (action.equals("viewDocs")) viewDocs(args, callback);
        else if (action.equals("allDocs")) allDocs(args, callback);
        else if (action.equals("get")) get(args, callback);
        else if (action.equals("getDocRev")) getDocRev(args, callback);

            //WRITE
		else if (action.equals("deleteLocal")) deleteLocal(args, callback);
        else if (action.equals("putAttachment")) putAttachment(args, callback);
        else if (action.equals("attachmentCount")) attachmentCount(args, callback);
        else if (action.equals("upsert")) upsert(args, callback);

        return true;
    }

    private void startPushReplication(final JSONArray args, final CallbackContext callback) {

    }

    private void pushReplicationIsRunning(final JSONArray args, final CallbackContext callback) {

    }

    private void deleteUserDbs(final JSONArray args, final CallbackContext callback) {

    }

    private void resetCallbacks(final JSONArray args, final CallbackContext callback) {
        //cancel callbacks
        for (CallbackContext context : callbacks) {
            PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
            result.setKeepCallback(false);
            context.sendPluginResult(result);
        }
        callbacks.clear();
        callback.success("reset callbacks");
    }

    private void changesDatabase(final JSONArray args, final CallbackContext callback) {
        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
        result.setKeepCallback(true);
        callback.sendPluginResult(result);

        callbacks.add(callback);

        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    final String dbName = args.getString(0);

                    if (dbs.get(dbName) != null) {
                        changeListeners.put(dbName, new Database.ChangeListener() {
                            @Override
                            public void changed(Database.ChangeEvent event) {
                                List<DocumentChange> changes = event.getChanges();
                                for (DocumentChange change : changes) {
                                    long lastSequence = dbs.get(dbName).getLastSequenceNumber();
                                    PluginResult result = new PluginResult(PluginResult.Status.OK,
                                            "{\"id\":" + "\"" + change.getDocumentId() + "\"" + ",\"is_delete\":" + change.isDeletion() + ",\"seq_num\":" + lastSequence + "}");
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
        });
    }

    private void changesReplication(final JSONArray args, final CallbackContext callback) {
        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
        result.setKeepCallback(true);
        callback.sendPluginResult(result);

        callbacks.add(callback);

        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    final String dbName = args.getString(0);

                    if (dbs.get(dbName) != null) {
                        replicationListeners.put(dbName + "_push", new Replication.ChangeListener() {
                            @Override
                            public void changed(Replication.ChangeEvent event) {
                                handleSyncStateEvent(event, dbName, "push", callback);
                            }
                        });
                        replicationListeners.put(dbName + "_pull", new Replication.ChangeListener() {
                            @Override
                            public void changed(Replication.ChangeEvent event) {
                                handleSyncStateEvent(event, dbName, "pull", callback);
                            }
                        });
                        replications.get(dbName + "_push").addChangeListener(replicationListeners.get(dbName + "_push"));
                        replications.get(dbName + "_pull").addChangeListener(replicationListeners.get(dbName + "_pull"));
                    }
                } catch (final Exception e) {
                    callback.error(e.getMessage());
                }
            }
        });
    }

    static private void handleSyncStateEvent(final Replication.ChangeEvent event, final String dbName, final String type, final CallbackContext callback) {
        String response;
        Replication.ReplicationStatus status = event.getStatus();
        if (event.getError() != null) {
            Throwable lastError = event.getError();
            if (lastError instanceof RemoteRequestResponseException) {
                RemoteRequestResponseException exception = (RemoteRequestResponseException) lastError;
                if (exception.getCode() == 401)
                    response = replicationResponse(dbName, "error_" + type, "REPLICATION_UNAUTHORIZED");
                else if (exception.getCode() == 404)
                    response = replicationResponse(dbName, "error_" + type, "REPLICATION_NOT_FOUND");
                else if (exception.getCode() > 0)
                    response = replicationResponse(dbName, "error_" + type, "REPLICATION_ERROR_CODE_" + exception.getCode());
                else
                    response = replicationResponse(dbName, "error_" + type, "REPLICATION_UNKNOWN_ERROR");
            } else response = replicationResponse(dbName, type, status.toString());
        } else response = replicationResponse(dbName, type, status.toString());

        PluginResult result = new PluginResult(PluginResult.Status.OK, response);
        result.setKeepCallback(true);
        callback.sendPluginResult(result);
    }

    static private String replicationResponse(String dbName, String type, String Message) {
        return "{\"db\":\"" + dbName + "\",\"type\":\"" + type + "\",\"message\":\"" + Message + "\"}";
    }

    private void compact(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    String dbName = args.getString(0);
                    dbs.get(dbName).compact();
                    callback.success("attachment saved!");
                } catch (final Exception e) {
                    callback.error(e.getMessage());
                }
            }
        });
    }

    private void info(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    String dbName = args.getString(0);
                    boolean isSqlite = false;

                    callback.success("{\"count\":" + dbs.get(dbName).getDocumentCount() + ",\"isSqlite\":\"" + isSqlite + "\"}");
                } catch (final Exception e) {
                    callback.error(e.getMessage());
                }
            }
        });
    }

    private void initCallerID(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    String dbName = args.getString(0);

                    //TODO get proper path for db string
                    if (callerIdDb != null) {
                        preparedInsert = null;
                        callerIdDb.close();
                    }
                    File file = new File(cordova.getActivity().getApplicationContext().getFilesDir() + "/callerIdName.txt");
                    file.delete();
                    file.createNewFile();
                    PrintWriter out = new PrintWriter(file);
                    out.println(dbName);
                    out.close();

                    callerIdDb = SQLiteDatabase.openOrCreateDatabase(cordova.getActivity().getApplicationContext().getFilesDir() + "/" + dbName + "_callerId.sqlite3", null);

                    //drop the old table so merges are not required
                    callerIdDb.execSQL("DROP TABLE IF EXISTS CallerId;");

                    //create the table
                    callerIdDb.execSQL(
                            "CREATE TABLE IF NOT EXISTS CallerId(" +
                                    "Phone BIGINT NOT NULL," +
                                    "Name CHAR(255) NOT NULL);"
                    );

                    //prep insert statement
                    String sql = "INSERT INTO CallerId (Phone, Name) VALUES (?, ?)";
                    preparedInsert = callerIdDb.compileStatement(sql);

                    callback.success("caller id initialized");
                } catch (Exception e) {
                    callback.success(e.getMessage());
                }
            }
        });
    }

    private void initDb(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    String dbName = args.getString(0);
                    Database userDb = dbmgr.getExistingDatabase(dbName);
                    if (userDb == null) {
                        DatabaseOptions options = new DatabaseOptions();
                        options.setCreate(true);
                        options.setStorageType(Manager.SQLITE_STORAGE);
                        dbs.put(dbName, dbmgr.openDatabase(dbName, options));
                    } else {
                        DatabaseOptions options = new DatabaseOptions();
                        dbs.put(dbName, dbmgr.openDatabase(dbName, options));
                    }

                    View primaryRecordView = dbs.get(dbName).getView("primaryRecord");
                    primaryRecordView.setMap(new Mapper() {
                        @Override
                        public void map(Map<String, Object> document, Emitter emitter) {
                            try{
                                if (document.get("type").equals("contact")){
                                    Map<String, Object> subDoc = new HashMap<String, Object>();
                                    subDoc.put("_id", document.get("_id"));
                                    subDoc.put("type", document.get("type"));
                                    subDoc.put("record_type", document.get("record_type"));
                                    subDoc.put("owners", document.get("owners"));
                                    subDoc.put("status_name", document.get("status_name"));
                                    subDoc.put("first_name", document.get("first_name"));
                                    subDoc.put("last_name", document.get("last_name"));
                                    emitter.emit("contact", subDoc);
                                }
                                else if (document.get("type").equals("job")){
                                    Map<String, Object> subDoc = new HashMap<String, Object>();
                                    subDoc.put("type", document.get("type"));
                                    subDoc.put("owners", document.get("owners"));
                                    subDoc.put("_id", document.get("_id"));
                                    subDoc.put("status_name", document.get("status_name"));
                                    subDoc.put("name", document.get("name"));
                                    emitter.emit("job", null);
                                }
                                else if (document.get("type").equals("task")){
                                    Map<String, Object> subDoc = new HashMap<String, Object>();
                                    subDoc.put("type", document.get("type"));
                                    subDoc.put("_id", document.get("_id"));
                                    subDoc.put("title", document.get("title"));
                                    subDoc.put("date_start", document.get("date_start"));
                                    subDoc.put("date_end", document.get("date_end"));
                                    emitter.emit("task", null);
                                }
                            }
                            catch(Exception e){}
                        }
                    }, "4");

                    callback.success("CBL db init success");
                } catch (final Exception e) {
                    callback.error(e.getMessage());
                }
            }
        });
    }

    private void lastSequence(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    String dbName = args.getString(0);
                    callback.success((int) dbs.get(dbName).getLastSequenceNumber());
                } catch (final Exception e) {
                    callback.error(e.getMessage());
                }
            }
        });
    }

    private void replicateFrom(JSONArray args, CallbackContext callback) {
    }

    private void replicateTo(JSONArray args, CallbackContext callback) {
    }

    private void reset(JSONArray args, CallbackContext callback) {
        this.onReset();
    }

    private void stopReplication(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
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
        });
    }

    private void sync(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    String dbName = args.getString(0);
                    URL syncUrl = new URL(args.getString(1));
                    String user = args.getString(2);
                    String pass = args.getString(3);

                    //stop any previously running replications
                    Authenticator auth = AuthenticatorFactory.createBasicAuthenticator(user, pass);

                    Replication oldPush = replications.get(dbName + "_push");
                    if (oldPush != null) {
                        oldPush.stop();
                        oldPush.setContinuous(true);
                        oldPush.restart();
                    } else {
                        Replication push = dbs.get(dbName).createPushReplication(syncUrl);
                        push.setContinuous(true);
                        push.setAuthenticator(auth);
                        push.start();
                        replications.put(dbName + "_push", push);
                    }

                    Replication oldPull = replications.get(dbName + "_pull");
                    if (oldPull != null) {
                        oldPull.stop();
                        oldPull.setContinuous(true);
                        oldPull.restart();
                    } else {
                        Replication pull = dbs.get(dbName).createPullReplication(syncUrl);
                        pull.setAuthenticator(auth);
                        pull.setContinuous(true);
                        pull.start();
                        replications.put(dbName + "_pull", pull);
                    }
                    callback.success("true");
                } catch (Exception e) {
                    callback.error(e.getMessage());
                }
            }
        });
    }

    private void buildViewDocs(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    final String dbName = args.getString(0);
                    Query query = dbs.get(dbName).getView("primaryRecord").createQuery();
                    query.setPrefetch(true);
                    query.setIndexUpdateMode(Query.IndexUpdateMode.AFTER);
                    List<Object> key = new ArrayList<Object>();
                    key.add("job");
                    query.setKeys(key);

                    QueryEnumerator primaryDocs = query.run();

                    callback.success("done");
                } catch (final Exception e) {
                    callback.error(e.getMessage());
                }
            }
        });
    }

    private void viewDocs(final JSONArray args, final CallbackContext callback) {
        PluginResult firstResult = new PluginResult(PluginResult.Status.NO_RESULT);
        firstResult.setKeepCallback(true);
        callback.sendPluginResult(firstResult);
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    final String dbName = args.getString(0);
                    final String type = args.getString(1);
                    final AtomicInteger numCompleted = new AtomicInteger();
                    ExecutorService executor = Executors.newFixedThreadPool(MAX_THREADS);

                    Query query = dbs.get(dbName).getView("primaryRecord").createQuery();
                    query.setPrefetch(true);
                    query.setIndexUpdateMode(Query.IndexUpdateMode.AFTER);
                    List<Object> key = new ArrayList<Object>();
                    key.add(type);
                    query.setKeys(key);

                    QueryEnumerator primaryDocs = query.run();
                    ArrayList<QueryRow> primaryDocList = new ArrayList<QueryRow>();
                    for (Iterator<QueryRow> it = primaryDocs; it.hasNext(); ) {
                        QueryRow row = it.next();
                        primaryDocList.add(row);
                    }
                    //running query
                    final List<List<QueryRow>> docBatches = ListUtils.partition(primaryDocList, 200);
                    for (final List<QueryRow> batch : docBatches) {
                        Future<Boolean> isComplete = executor.submit(new Callable<Boolean>() {
                            @Override
                            public Boolean call() throws Exception {
                                try {
                                    final ArrayList<String> responseBuffer = new ArrayList<String>();

                                    for (QueryRow record : batch) {
                                        try {
                                            responseBuffer.add(mapper.writeValueAsString(record.asJSONDictionary()));
                                        }
                                        catch(Exception e){}
                                    }
                                    String res = "[" + TextUtils.join(",", responseBuffer) + "]";
                                    PluginResult result = new PluginResult(PluginResult.Status.OK, res.getBytes("UTF-8"));
                                    result.setKeepCallback(true);
                                    callback.sendPluginResult(result);
                                    numCompleted.incrementAndGet();
                                } catch (Exception e) {
                                    PluginResult result = new PluginResult(PluginResult.Status.ERROR, e.getMessage());
                                    result.setKeepCallback(false);
                                    callback.sendPluginResult(result);
                                    return false;
                                }
                                return true;
                            }
                        });
                        runnerCount += 1;
                        if (runnerCount >= MAX_THREADS) {
                            isComplete.get();
                            runnerCount = 0;
                        }
                    }
                    executor.submit(new Callable<Boolean>() {
                        @Override
                        public Boolean call() throws Exception {
                            while (numCompleted.get() < docBatches.size()) {
                                Thread.sleep(1000);
                            }
                            PluginResult finalResult = new PluginResult(PluginResult.Status.OK, "complete");
                            finalResult.setKeepCallback(false);
                            callback.sendPluginResult(finalResult);
                            runnerCount = 0;
                            return true;
                        }
                    });
                } catch (Exception e) {
                    PluginResult result = new PluginResult(PluginResult.Status.ERROR, e.getMessage());
                    result.setKeepCallback(false);
                    callback.sendPluginResult(result);
                }
            }
        });
    }

    private void allDocs(final JSONArray args, final CallbackContext callback) {
        PluginResult firstResult = new PluginResult(PluginResult.Status.NO_RESULT);
        firstResult.setKeepCallback(true);
        callback.sendPluginResult(firstResult);
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    final String dbName = args.getString(0);
                    final AtomicInteger numCompleted = new AtomicInteger();
                    ExecutorService executor = Executors.newFixedThreadPool(MAX_THREADS);

                    //get an array of all database ids
                    Query query = dbs.get(dbName).createAllDocumentsQuery();
                    query.setAllDocsMode(Query.AllDocsMode.ALL_DOCS);
                    query.setPrefetch(false);
                    QueryEnumerator allIds = query.run();
                    ArrayList<Object> idList = new ArrayList<Object>();
                    for (Iterator<QueryRow> it = allIds; it.hasNext(); ) {
                        QueryRow row = it.next();
                        idList.add(row.getDocumentId());
                    }

                    //iterate over the idBatches
                    final List<List<Object>> idBatches = ListUtils.partition(idList, 1000);
                    for (final List<Object> batch : idBatches) {
                        Future<Boolean> isComplete = executor.submit(new Callable<Boolean>() {
                            @Override
                            public Boolean call() throws Exception {
                                Query query = dbs.get(dbName).createAllDocumentsQuery();
                                query.setAllDocsMode(Query.AllDocsMode.ALL_DOCS);
                                query.setPrefetch(true);
                                query.setKeys(batch);
                                try {
                                    QueryEnumerator allDocsQuery = query.run();
                                    final ArrayList<String> responseBuffer = new ArrayList<String>();

                                    for (Iterator<QueryRow> it = allDocsQuery; it.hasNext(); ) {
										QueryRow row = it.next();
										try {
                                            Map<String, Object> dict = row.asJSONDictionary();
										    responseBuffer.add(mapper.writeValueAsString(dict));
                                            //send record to callerID sqlite table
                                            try{
                                                callerIDInsert(dict);
                                            }
                                            catch(Exception e){
                                                RaygunClient.send(e);
                                            }
										}
										catch(Exception e){
										    //HashMap<String, String> extraData = new HashMap<String, String>();
										    //extraData.put("id",row.getDocumentId());
										    //extraData.put("rev",row.getDocumentRevisionId());
										    //RaygunClient.send(e,null, extraData);
										}
                                    }
								    String res = "[" + TextUtils.join(",", responseBuffer) + "]";
								    PluginResult result = new PluginResult(PluginResult.Status.OK, res.getBytes("UTF-8"));
                                    result.setKeepCallback(true);
                                    callback.sendPluginResult(result);
                                    numCompleted.incrementAndGet();
                                } catch (Exception e) {
                                    PluginResult result = new PluginResult(PluginResult.Status.ERROR, e.getMessage());
                                    result.setKeepCallback(false);
                                    callback.sendPluginResult(result);
                                    return false;
                                }
                                return true;
                            }
                        });
                        runnerCount += 1;
                        if (runnerCount >= MAX_THREADS) {
                            isComplete.get();
                            runnerCount = 0;
                        }
                    }
                    executor.submit(new Callable<Boolean>() {
                        @Override
                        public Boolean call() throws Exception {
                            while (numCompleted.get() < idBatches.size()) {
                                Thread.sleep(1000);
                            }
                            PluginResult finalResult = new PluginResult(PluginResult.Status.OK, "complete");
                            finalResult.setKeepCallback(false);
                            callback.sendPluginResult(finalResult);
                            runnerCount = 0;
                            return true;
                        }
                    });
                } catch (Exception e) {
                    PluginResult result = new PluginResult(PluginResult.Status.ERROR, e.getMessage());
                    result.setKeepCallback(false);
                    callback.sendPluginResult(result);
                }
            }
        });
    }

    private void callerIDInsert(Map<String, Object> row) {
        HashMap<String, Object> doc = (HashMap<String, Object>) row.get("doc");
        String type = (String) doc.get("type");
        if (type != null && type.contentEquals("contact")) {
            String name = doc.get("first_name") != null ? (String) doc.get("first_name") : "";
            name = doc.get("last_name") != null ? name + " " + doc.get("last_name") : name;
            if (name.length() == 0)
                name = doc.get("company") != null ? (String) doc.get("company") : "";
            if (name.length() == 0) name = "Blank JobNimbus Contact";

            try {
                String home = (String) doc.get("home_phone");
                if (home != null && home.length() > 0) {
                    if (home != null && home.length() > 0) executeCallerIdSqlInsert(home, name);
                }
            } catch (Exception e) {
                RaygunClient.send(e);
            }
            try {
                String work = (String) doc.get("work_phone");
                if (work != null && work.length() > 0) {
                    if (work != null && work.length() > 0) executeCallerIdSqlInsert(work, name);
                }
            } catch (Exception e) {
                RaygunClient.send(e);
            }
            try {
                String mobile = (String) doc.get("mobile_phone");
                if (mobile != null && mobile.length() > 0) {
                    if (mobile != null && mobile.length() > 0) executeCallerIdSqlInsert(mobile, name);
                }
            } catch (Exception e) {
                RaygunClient.send(e);
            }
        }
    }

    private void executeCallerIdSqlInsert(String phone, String name){
        if(preparedInsert == null || phone == null || name == null){
            try{
                RaygunClient.send(new Exception("Failed to insert callerID data: " + phone + " : " + name));
            }
            catch(Exception e){
                RaygunClient.send(e);
            }
        }
        else {
            String[] parts = phone.split("x");
            Long numPhone = Long.valueOf(parts[0].substring(0, Math.min(parts[0].length(), 11)).replaceAll("[^0-9]", ""));
            preparedInsert.bindLong(1, numPhone); // These match to the two question marks in the sql string
            preparedInsert.bindString(2, name);
            preparedInsert.executeInsert();
        }
    }

    private void get(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    String dbName = args.getString(0);
                    String id = args.getString(1);
                    String isLocal = args.getString(2);

                    if (isLocal.equals("true")) {
                        Map<String, Object> localDoc = dbs.get(dbName).getExistingLocalDocument(id);
                        if (localDoc != null) {
                            callback.success(mapper.writeValueAsString(localDoc));
                        } else callback.error("null");
                    } else {
                        Document doc = dbs.get(dbName).getExistingDocument(id);
                        if (doc != null) {
                            String jsonString = mapper.writeValueAsString(doc.getProperties());
                            callback.success(jsonString);
                        } else callback.error("null");
                    }
                } catch (final Exception e) {
                    RaygunClient.send(e);
                    callback.error("null");
                }
            }
        });
    }

    private void getDocRev(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    String dbName = args.getString(0);
                    String id = args.getString(1);

                    Document doc = dbs.get(dbName).getExistingDocument(id);
                    if (doc != null) {
                        callback.success(doc.getCurrentRevisionId());
                    } else callback.error("null");

                } catch (final Exception e) {
                    callback.error(e.getMessage());
                }
            }
        });
    }
	
	private void deleteLocal(final JSONArray args, final CallbackContext callback) {
	        cordova.getThreadPool().execute(new Runnable() {
	            public void run() {
	                try {
	                    String dbName = args.getString(0);
	                    String id = args.getString(1);
	                    dbs.get(dbName).deleteLocalDocument(id);
	                    callback.success("sucess");
	                } catch (final Exception e) {
	                    callback.error("delete local doc failure");
	                }
	            }
	        });
	    }

    private void putAttachment(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    String dbName = args.getString(0);
                    String filePath = cordova.getActivity().getApplicationContext().getFilesDir() + "/" + args.getString(5) + "/" + args.getString(2);
                    FileInputStream stream = new FileInputStream(filePath);
                    Document doc = dbs.get(dbName).getDocument(args.getString(1));
                    UnsavedRevision newRev = doc.getCurrentRevision().createRevision();
                    newRev.setAttachment(args.getString(3), args.getString(4), stream);
                    newRev.save();
                    callback.success("success");
                } catch (final Exception e) {
                    RaygunClient.send(e);
                    callback.error("putAttachment failure");
                }
            }
        });
    }

    private void attachmentCount(final JSONArray args, final CallbackContext callback){
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    String dbName = args.getString(0);
                    Document doc = dbs.get(dbName).getDocument(args.getString(1));
                    Revision rev = doc.getCurrentRevision();
                    List<Attachment> allAttachments = rev.getAttachments();
                    callback.success(allAttachments.size());
                } catch (final Exception e) {
                    callback.success(0);
                }
            }
        });
    }

    private void upsert(final JSONArray args, final CallbackContext callback) {
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                try {
                    String dbName = args.getString(0);
                    String id = args.getString(1);
                    String jsonString = args.getString(2);
                    String isLocal = args.getString(3);

                    if (isLocal.equals("local")) {
                        Map<String, Object> mapDoc = mapper.readValue(jsonString, new TypeReference<Map<String, Object>>() {
                        });
                        dbs.get(dbName).putLocalDocument(id, mapDoc);
                        callback.success("local upsert successful");
                    } else {
                        Document doc = dbs.get(dbName).getExistingDocument(id);
                        //if doc does not exist
                        if (doc == null) {
                            final Map<String, Object> mapDoc = mapper.readValue(jsonString, new TypeReference<Map<String, Object>>() {
                            });
                            Document document = dbs.get(dbName).getDocument(id);
                            document.putProperties(mapDoc);
                            callback.success("upsert successful");
                        }
                        //doc exists, force update
                        else {
                            final Map<String, Object> mapDoc = mapper.readValue(jsonString, new TypeReference<Map<String, Object>>() {
                            });
                            doc.update(new Document.DocumentUpdater() {
                                @Override
                                public boolean update(UnsavedRevision newRevision) {
                                    newRevision.setUserProperties(mapDoc);
                                    callback.success("upsert successful");
                                    return true;
                                }
                            });
                        }
                    }
                } catch (final Exception e) {
                    callback.error(e.getMessage());
                }
            }
        });
    }

    private Manager startCBLite(Context context) {
        try {
            //Manager.enableLogging(Log.TAG, Log.VERBOSE);
            //Manager.enableLogging(Log.TAG_SYNC, Log.VERBOSE);
            //Manager.enableLogging(Log.TAG_REMOTE_REQUEST, Log.VERBOSE);
            //Manager.enableLogging(Log.TAG_CHANGE_TRACKER, Log.VERBOSE);
            //Manager.enableLogging(Log.TAG_BLOB_STORE, Log.VERBOSE);
            //Manager.enableLogging(Log.TAG_DATABASE, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_QUERY, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_VIEW, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_LISTENER, Log.VERBOSE);
//            Manager.enableLogging(Log.TAG_MULTI_STREAM_WRITER, Log.VERBOSE);
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
