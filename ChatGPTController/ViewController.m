//
//  ViewController.m
//  ChatGPTController
//
//  Created by 早川強 on 2025/11/05.
//

#import "ViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface ViewController ()
@property (strong) NSWindow *progressWindow;
@property (strong) NSProgressIndicator *progressIndicator;
@property (strong) NSButton *cancelButton;
@property (assign) BOOL shouldCancelBatch;
@end

@implementation ViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // 保存された API キーを復元
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"OpenAI_API_Key"];
    if (savedKey) self.apiKeyField.stringValue = savedKey;

    // 初期値
    self.modelField.stringValue = @"gpt-4o-mini";
    self.temperatureField.stringValue = @"0.7";
    self.maxTokensField.stringValue = @"512";
    self.systemMessageField.stringValue = @"あなたは有能なアシスタントです。";

    self.history = [NSMutableArray array];
    self.historyTable.delegate = self;
    self.historyTable.dataSource = self;

    NSTableColumn *col = [self.historyTable tableColumnWithIdentifier:@"PromptColumn"];
    col.title = @"履歴";
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

#pragma mark - ChatGPT API (Single Prompt)

- (IBAction)sendToChatGPT:(id)sender {

    NSString *apiKey = self.apiKeyField.stringValue;
    if (apiKey.length == 0) {
        self.historyTextView.string = @"APIキーを入力してください。\n";
        return;
    }

    // UI 状態
    self.sendButton.enabled = NO;
    [self.loadingIndicator startAnimation:nil];
    self.historyTextView.string = @"処理中...\n";

    // API キー保存
    [[NSUserDefaults standardUserDefaults] setObject:apiKey forKey:@"OpenAI_API_Key"];

    NSString *model = self.modelField.stringValue.length ? self.modelField.stringValue : @"gpt-4o-mini";
    NSString *temperatureStr = self.temperatureField.stringValue.length ? self.temperatureField.stringValue : @"0.7";
    NSString *maxTokensStr = self.maxTokensField.stringValue.length ? self.maxTokensField.stringValue : @"512";
    NSString *systemMessage = self.systemMessageField.stringValue.length ? self.systemMessageField.stringValue : @"あなたは有能なアシスタントです。";
    NSString *prompt = self.promptField.stringValue;

    if (prompt.length == 0) {
        self.historyTextView.string = @"プロンプトを入力してください。\n";
        return;
    }

    float temperature = temperatureStr.floatValue;
    NSInteger maxTokens = maxTokensStr.integerValue;

    NSURL *url = [NSURL URLWithString:@"https://api.openai.com/v1/chat/completions"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];

    NSDictionary *body = @{
        @"model": model,
        @"temperature": @(temperature),
        @"max_tokens": @(maxTokens),
        @"messages": @[
            @{@"role": @"system", @"content": systemMessage},
            @{@"role": @"user", @"content": prompt}
        ]
    };

    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionDataTask *task =
    [[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimation:nil];
            self.sendButton.enabled = YES;

            if (error) {
                self.historyTextView.string = [NSString stringWithFormat:@"エラー: %@\n", error.localizedDescription];
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *content = json[@"choices"][0][@"message"][@"content"] ?: @"応答なし";

            self.resultView.string = content;

            NSDictionary *entry = @{
                @"prompt": prompt,
                @"response": content,
                @"model": model,
                @"temperature": temperatureStr,
                @"max_tokens": maxTokensStr,
                @"system": systemMessage
            };

            [self.history addObject:entry];
            [self.historyTable reloadData];
        });
    }];

    [task resume];
}

#pragma mark - Chat API Core

- (void)runChatWithPrompt:(NSString *)prompt completion:(void (^)(NSString *))completion {

    NSString *apiKey = self.apiKeyField.stringValue;
    if (!apiKey.length) {
        completion(@"APIキーが設定されていません");
        return;
    }

    NSString *model = self.modelField.stringValue ?: @"gpt-4o-mini";
    float temperature = self.temperatureField.stringValue.floatValue ?: 0.7;
    NSInteger maxTokens = self.maxTokensField.stringValue.integerValue ?: 512;
    NSString *systemMessage = self.systemMessageField.stringValue ?: @"あなたは有能なアシスタントです。";

    NSURL *url = [NSURL URLWithString:@"https://api.openai.com/v1/chat/completions"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];

    NSDictionary *body = @{
        @"model": model,
        @"temperature": @(temperature),
        @"max_tokens": @(maxTokens),
        @"messages": @[
            @{@"role": @"system", @"content": systemMessage},
            @{@"role": @"user", @"content": prompt}
        ]
    };

    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionDataTask *task =
    [[NSURLSession sharedSession] dataTaskWithRequest:req
                                    completionHandler:^(NSData *data, NSURLResponse *res, NSError *error) {

        if (error) {
            completion([NSString stringWithFormat:@"エラー: %@", error.localizedDescription]);
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *content = json[@"choices"][0][@"message"][@"content"] ?: @"応答なし";

        completion(content);
    }];
    [task resume];
}

- (NSString *)runChatSynchronouslyWithPrompt:(NSString *)prompt {

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSString *result = nil;

    [self runChatWithPrompt:prompt completion:^(NSString *response) {
        result = response;
        dispatch_semaphore_signal(sema);
    }];

    dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));

    return result ?: @"(no response)";
}

#pragma mark - Entry Operations

- (IBAction)newEntry:(id)sender {
    self.promptField.stringValue = @"";
    self.resultView.string = @"";
    self.modelField.stringValue = @"gpt-4o-mini";
    self.temperatureField.stringValue = @"0.7";
    self.maxTokensField.stringValue = @"512";
    self.systemMessageField.stringValue = @"あなたは有能なアシスタントです。";
    [self.historyTable deselectAll:nil];
}

- (IBAction)duplicateEntry:(id)sender {
    NSInteger row = self.historyTable.selectedRow;
    if (row < 0 || row >= self.history.count) return;

    NSDictionary *entry = self.history[row];
    NSMutableDictionary *copy = [entry mutableCopy];

    [self.history addObject:copy];
    [self.historyTable reloadData];
    [self.historyTable selectRowIndexes:[NSIndexSet indexSetWithIndex:self.history.count - 1]
                   byExtendingSelection:NO];
}

#pragma mark - History File I/O

- (IBAction)saveHistoryAs:(id)sender {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedContentTypes = @[[UTType typeWithIdentifier:@"com.apple.property-list"]];
    panel.nameFieldStringValue = @"ChatGPT_History.plist";

    [panel beginWithCompletionHandler:^(NSModalResponse r) {
        if (r == NSModalResponseOK)
            [self.history writeToURL:panel.URL atomically:YES];
    }];
}

- (IBAction)openHistoryFile:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedContentTypes = @[[UTType typeWithIdentifier:@"com.apple.property-list"]];

    [panel beginWithCompletionHandler:^(NSModalResponse r) {
        if (r == NSModalResponseOK) {
            NSArray *loaded = [NSArray arrayWithContentsOfURL:panel.URL];
            if (loaded) {
                self.history = [loaded mutableCopy];
                [self.historyTable reloadData];
            }
        }
    }];
}

- (IBAction)exportHistoryAsText:(id)sender {

    NSSavePanel *panel = [NSSavePanel savePanel];
    if (@available(macOS 12.0, *)) {
        panel.allowedContentTypes = @[[UTType typeWithIdentifier:@"public.comma-separated-values-text"]];
    } else {
        panel.allowedFileTypes = @[@"csv"];
    }

    panel.nameFieldStringValue = @"ChatGPT_History.csv";

    [panel beginWithCompletionHandler:^(NSModalResponse r) {
        if (r != NSModalResponseOK) return;

        NSMutableString *output = [NSMutableString string];
        [output appendString:@"\"Prompt\"\t\"Response\"\t\"Model\"\t\"Temperature\"\t\"MaxTokens\"\n"];

        for (NSDictionary *entry in self.history) {

            NSString *(^escape)(NSString *) = ^NSString *(NSString *text) {
                if (!text) return @"";
                NSString *e = [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
                return [NSString stringWithFormat:@"\"%@\"", e];
            };

            [output appendFormat:@"%@\t%@\t%@\t%@\t%@\n",
             escape(entry[@"prompt"]),
             escape(entry[@"response"]),
             escape(entry[@"model"]),
             escape([NSString stringWithFormat:@"%@", entry[@"temperature"]]),
             escape([NSString stringWithFormat:@"%@", entry[@"max_tokens"]])
            ];
        }

        // BOM 付 UTF-8
        NSMutableData *final = [NSMutableData dataWithData:[@"\uFEFF" dataUsingEncoding:NSUTF8StringEncoding]];
        [final appendData:[output dataUsingEncoding:NSUTF8StringEncoding]];
        [final writeToURL:panel.URL atomically:YES];
    }];
}

- (IBAction)deleteSelectedHistory:(id)sender {
    NSInteger row = self.historyTable.selectedRow;
    if (row >= 0 && row < self.history.count) {
        [self.history removeObjectAtIndex:row];
        [self.historyTable reloadData];
    }
}

#pragma mark - Folder Batch Execute

- (IBAction)loadFolderAndExecute:(id)sender {

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = NO;

    [panel beginWithCompletionHandler:^(NSModalResponse r) {
        if (r != NSModalResponseOK) return;

        NSURL *folderURL = panel.URL;

        // 保存先フォルダ選択
        NSOpenPanel *savePanel = [NSOpenPanel openPanel];
        savePanel.canChooseDirectories = YES;
        savePanel.canChooseFiles = NO;
        savePanel.canCreateDirectories = YES;
        savePanel.title = @"保存先フォルダを選んでください";

        [savePanel beginWithCompletionHandler:^(NSModalResponse r2) {
            if (r2 == NSModalResponseOK)
                [self processFolderBatch:folderURL saveTo:savePanel.URL];
        }];
    }];
}

- (void)processFolderBatch:(NSURL *)folderURL saveTo:(NSURL *)saveURL {

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{

        __strong typeof(self) strongSelf = self;
        if (!strongSelf) return;

        // UI値（prompt）を取得
        __block NSString *userPromptTemplate = @"";
        dispatch_sync(dispatch_get_main_queue(), ^{
            userPromptTemplate = [strongSelf.promptField.stringValue copy];
        });

        // フォルダから txt を取得
        NSError *err = nil;
        NSArray *files =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:folderURL
                                       includingPropertiesForKeys:nil
                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                            error:&err];

        if (err || !files.count) {
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.historyTextView.string = @"フォルダ内にファイルがありません。\n";
            });
            return;
        }

        NSPredicate *pred = [NSPredicate predicateWithFormat:@"pathExtension=='txt'"];
        files = [files filteredArrayUsingPredicate:pred];

        if (!files.count) {
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.historyTextView.string = @"フォルダに txt ファイルがありません。\n";
            });
            return;
        }

        // 進捗ダイアログ
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf showProgressDialogWithTotal:files.count];
        });

        // 各ファイル処理
        NSInteger index = 0;

        for (NSURL *fileURL in files) {

            if (strongSelf.shouldCancelBatch) break;

            NSError *readErr = nil;
            NSString *content = [NSString stringWithContentsOfURL:fileURL
                                                          encoding:NSUTF8StringEncoding
                                                             error:&readErr];

            if (!content.length) {
                [strongSelf appendBatchLog:[NSString stringWithFormat:@"空ファイル: %@", fileURL.lastPathComponent]];
                index++;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf.progressIndicator setDoubleValue:index];
                });
                continue;
            }

            NSString *finalPrompt =
            userPromptTemplate.length ?
            [NSString stringWithFormat:@"%@\n%@", userPromptTemplate, content]
            : content;

            NSString *response = [strongSelf runChatSynchronouslyWithPrompt:finalPrompt];

            [strongSelf saveHistoryWithPrompt:finalPrompt response:response];

            NSURL *outURL = [saveURL URLByAppendingPathComponent:fileURL.lastPathComponent];
            NSError *saveErr = nil;

            BOOL ok = [response writeToURL:outURL
                                atomically:YES
                                  encoding:NSUTF8StringEncoding
                                     error:&saveErr];

            if (!ok || saveErr) {
                [strongSelf appendBatchLog:[NSString stringWithFormat:@"保存失敗: %@", fileURL.lastPathComponent]];
            } else {
                [strongSelf appendBatchLog:[NSString stringWithFormat:@"保存完了: %@", fileURL.lastPathComponent]];
            }

            index++;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf.progressIndicator setDoubleValue:index];
            });
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf.view.window endSheet:strongSelf.progressWindow];
            strongSelf.progressWindow = nil;
        });
    });
}

- (void)appendBatchLog:(NSString *)msg {
    if (!self.historyTextView) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        self.historyTextView.string =
        [self.historyTextView.string stringByAppendingFormat:@"%@\n", msg];

        [self.historyTextView scrollRangeToVisible:
         NSMakeRange(self.historyTextView.string.length, 0)];
    });
}

#pragma mark - Text File (One-by-One Prompts)

- (IBAction)loadPromptFileAndExecute:(id)sender {

    NSString *apiKey = self.apiKeyField.stringValue;
    if (!apiKey.length) {
        self.historyTextView.string = @"APIキーを入力してください。\n";
        return;
    }

    [[NSUserDefaults standardUserDefaults] setObject:apiKey forKey:@"OpenAI_API_Key"];

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"txt", @"text", @"public.plain-text"];

    [panel beginWithCompletionHandler:^(NSModalResponse r) {
        if (r == NSModalResponseOK)
            [self executePromptsFromFile:panel.URL];
    }];
}

- (void)executePromptsFromFile:(NSURL *)fileURL {

    NSError *err = nil;
    NSString *contents = [NSString stringWithContentsOfURL:fileURL
                                                  encoding:NSUTF8StringEncoding
                                                     error:&err];

    if (err) {
        NSLog(@"ファイル読み込みエラー: %@", err.localizedDescription);
        return;
    }

    NSArray *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *prompts = [NSMutableArray array];

    NSString *suffix = self.promptField.stringValue.length ? self.promptField.stringValue : @"教えて";

    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length) {
            NSString *full = [NSString stringWithFormat:@"%@について、%@", trimmed, suffix];
            [prompts addObject:full];
        }
    }

    [self runSequentialPrompts:prompts currentIndex:0];
}

- (void)runSequentialPrompts:(NSArray<NSString *> *)prompts currentIndex:(NSInteger)index {

    if (index == 0)
        [self showProgressDialogWithTotal:prompts.count];

    if (self.shouldCancelBatch || index >= prompts.count) {
        [self.view.window endSheet:self.progressWindow];
        self.progressWindow = nil;
        return;
    }

    NSString *prompt = prompts[index];

    [self sendPromptToChatGPT:prompt completion:^(NSString *response) {
        [self appendToHistoryWithPrompt:prompt response:response];
        [self updateProgress:index + 1 total:prompts.count];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            [self runSequentialPrompts:prompts currentIndex:index + 1];
        });
    }];
}

// ⚠️ runChatWithPrompt と完全に役割重複（不要の可能性）
- (void)sendPromptToChatGPT:(NSString *)prompt completion:(void (^)(NSString *response))completion {
    [self runChatWithPrompt:prompt completion:^(NSString *result) {
        completion(result ?: @"(no response)");
    }];
}

#pragma mark - History Handling

- (void)saveHistoryWithPrompt:(NSString *)prompt response:(NSString *)response {

    if (!prompt || !response) return;

    NSDictionary *entry = @{
        @"prompt": prompt,
        @"response": response,
        @"model": self.modelField.stringValue ?: @"",
        @"temperature": self.temperatureField.stringValue ?: @"",
        @"max_tokens": self.maxTokensField.stringValue ?: @"",
        @"system": self.systemMessageField.stringValue ?: @""
    };

    [self.history addObject:entry];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.historyTable reloadData];
    });
}

- (void)appendToHistoryWithPrompt:(NSString *)prompt response:(NSString *)response {
    [self saveHistoryWithPrompt:prompt response:response];
}

// ⚠️ appendBatchLog の下位互換？ 不要の可能性
- (void)appendHistory:(NSString *)text {
    if (!self.historyTextView) return;

    self.historyTextView.string =
    [self.historyTextView.string stringByAppendingFormat:@"%@\n", text];

    [self.historyTextView scrollRangeToVisible:
     NSMakeRange(self.historyTextView.string.length, 0)];
}

#pragma mark - Batch Progress UI

- (void)showProgressDialogWithTotal:(NSInteger)totalCount {

    self.shouldCancelBatch = NO;

    NSRect frame = NSMakeRect(0, 0, 400, 120);
    self.progressWindow =
    [[NSWindow alloc] initWithContentRect:frame
                                styleMask:NSWindowStyleMaskTitled
                                  backing:NSBackingStoreBuffered
                                    defer:NO];

    self.progressWindow.title = @"バッチ実行中";
    [self.progressWindow center];

    NSView *content = self.progressWindow.contentView;

    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 70, 360, 20)];
    label.stringValue = @"ChatGPTに順次問い合わせ中...";
    label.bezeled = NO;
    label.editable = NO;
    label.drawsBackground = NO;
    [content addSubview:label];

    self.progressIndicator =
    [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(20, 40, 360, 20)];
    self.progressIndicator.indeterminate = NO;
    self.progressIndicator.minValue = 0;
    self.progressIndicator.maxValue = totalCount;
    self.progressIndicator.doubleValue = 0;
    self.progressIndicator.style = NSProgressIndicatorStyleBar;
    [content addSubview:self.progressIndicator];

    self.cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(150, 5, 100, 30)];
    self.cancelButton.title = @"キャンセル";
    self.cancelButton.bezelStyle = NSBezelStyleRounded;
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancelBatchProcess);
    [content addSubview:self.cancelButton];

    [self.view.window beginSheet:self.progressWindow completionHandler:nil];
}

- (void)cancelBatchProcess {
    self.shouldCancelBatch = YES;
    [self.view.window endSheet:self.progressWindow];
    self.progressWindow = nil;
}

- (void)updateProgress:(NSInteger)current total:(NSInteger)total {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressIndicator.doubleValue = current;
    });
}

#pragma mark - NSTextField Delegate

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
    if (obj.object == self.apiKeyField)
        self.apiKeyField.stringValue = @"";
}

#pragma mark - TableView DataSource & Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.history.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {

    NSDictionary *entry = self.history[row];
    NSString *prompt = entry[@"prompt"];

    if (prompt.length > 40)
        prompt = [[prompt substringToIndex:40] stringByAppendingString:@"..."];

    return prompt;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {

    NSInteger row = self.historyTable.selectedRow;
    if (row < 0 || row >= self.history.count) return;

    NSDictionary *entry = self.history[row];

    self.promptField.stringValue = entry[@"prompt"] ?: @"";
    self.resultView.string = entry[@"response"] ?: @"";
    self.modelField.stringValue = entry[@"model"] ?: @"gpt-4o-mini";
    self.temperatureField.stringValue = entry[@"temperature"] ?: @"0.7";
    self.maxTokensField.stringValue = entry[@"max_tokens"] ?: @"512";
    self.systemMessageField.stringValue = entry[@"system"] ?: @"あなたは有能なアシスタントです。";
}

@end
