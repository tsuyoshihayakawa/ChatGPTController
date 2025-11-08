//
//  ViewController.m
//  ChatGPTController
//
//  Created by 早川強 on 2025/11/05.
//

#import "ViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // 🔹 起動時に保存されたAPIキーを読み込む
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedKey = [defaults stringForKey:@"OpenAI_API_Key"];
    if (savedKey) {
        self.apiKeyField.stringValue = savedKey;
    }
    
    self.modelField.stringValue = @"gpt-4o-mini";
    self.temperatureField.stringValue = @"0.7";
    self.maxTokensField.stringValue = @"512";
    self.systemMessageField.stringValue = @"あなたは有能なアシスタントです。";
    
    self.history = [NSMutableArray array];
    self.historyTable.delegate = self;
    self.historyTable.dataSource = self;

    // テーブルのカラム設定（Storyboardで設定している場合は不要）
    NSTableColumn *col = [self.historyTable tableColumnWithIdentifier:@"PromptColumn"];
    col.title = @"履歴";
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)sendToChatGPT:(id)sender {
    NSString *apiKey = self.apiKeyField.stringValue;
    if (apiKey.length == 0) {
        self.resultView.string = @"APIキーを入力してください。";
        return;
    }

    // 🔹 ボタンを無効化＆インジケータ開始
    self.sendButton.enabled = NO;
    [self.loadingIndicator startAnimation:nil];
    self.resultView.string = @"処理中...";
    
    // 🔹 APIキーを保存
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:apiKey forKey:@"OpenAI_API_Key"];
    [defaults synchronize];

    NSString *model = self.modelField.stringValue.length > 0 ? self.modelField.stringValue : @"gpt-4o-mini";
    NSString *temperatureStr = self.temperatureField.stringValue.length > 0 ? self.temperatureField.stringValue : @"0.7";
    NSString *maxTokensStr = self.maxTokensField.stringValue.length > 0 ? self.maxTokensField.stringValue : @"512";
    NSString *systemMessage = self.systemMessageField.stringValue.length > 0 ? self.systemMessageField.stringValue : @"あなたは有能なアシスタントです。";
    NSString *prompt = self.promptField.stringValue;

    if (apiKey.length == 0 || prompt.length == 0) {
        self.resultView.string = @"APIキーとプロンプトを入力してください。";
        return;
    }

    float temperature = [temperatureStr floatValue];
    NSInteger maxTokens = [maxTokensStr integerValue];

    NSURL *url = [NSURL URLWithString:@"https://api.openai.com/v1/chat/completions"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
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
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [request setHTTPBody:jsonData];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // 🔹 インジケータ停止＆ボタン有効化
            [self.loadingIndicator stopAnimation:nil];
            self.sendButton.enabled = YES;

            if (error) {
                self.resultView.string = [NSString stringWithFormat:@"エラー: %@", error.localizedDescription];
                return;
            }

            NSLog(@"Request URL: %@", url);
            NSLog(@"Headers: %@", request.allHTTPHeaderFields);
            
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *content = json[@"choices"][0][@"message"][@"content"];
            if (!content) content = @"応答なし";
            self.resultView.string = content;
            
            NSDictionary *entry = @{
                @"prompt": prompt,
                @"response": content ?: @"",
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

- (NSString *)runChatSynchronouslyWithPrompt:(NSString *)prompt {
    NSLog(@"[ViewController] runChatSynchronouslyWithPrompt: %@", prompt);
    // 実際のAPI呼び出し前の動作確認用
    return [NSString stringWithFormat:@"Echo: %@", prompt];
}

#pragma IBAction ==================================

- (IBAction)newEntry:(id)sender {
    self.promptField.stringValue = @"";
    self.resultView.string = @"";
    self.modelField.stringValue = @"gpt-4o-mini";
    self.temperatureField.stringValue = @"0.7";
    self.maxTokensField.stringValue = @"512";
    self.systemMessageField.stringValue = @"あなたは有能なアシスタントです。";
    [self.historyTable deselectAll:nil];
    self.resultView.string = @"";
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

#pragma mark - 保存／読み込み／書き出し

// 🔹 「名前をつけて保存」(plist)
- (IBAction)saveHistoryAs:(id)sender {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedContentTypes = @[[UTType typeWithIdentifier:@"com.apple.property-list"]];
    panel.nameFieldStringValue = @"ChatGPT_History.plist";
    [panel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSURL *url = panel.URL;
            [self.history writeToURL:url atomically:YES];
            NSLog(@"✅ 保存: %@", url.path);
        }
    }];
}

// 🔹 「読み込み」（plist）
- (IBAction)openHistoryFile:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedContentTypes = @[[UTType typeWithIdentifier:@"com.apple.property-list"]];
    [panel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSURL *url = panel.URL;
            NSArray *loaded = [NSArray arrayWithContentsOfURL:url];
            if (loaded) {
                self.history = [loaded mutableCopy];
                [self.historyTable reloadData];
                NSLog(@"📂 読み込み: %@", url.path);
            } else {
                NSLog(@"⚠️ 読み込み失敗: %@", url.path);
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

    [panel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {

            NSMutableString *output = [NSMutableString string];

            // 🔹 ヘッダー
            [output appendString:@"\"Prompt\"\t\"Response\"\t\"Model\"\t\"Temperature\"\t\"MaxTokens\"\n"];

            for (NSDictionary *entry in self.history) {
                NSString *(^escape)(NSString *) = ^NSString *(NSString *text) {
                    if (!text) return @"";
                    // ダブルクォートは "" に置換（CSV規格）
                    NSString *escaped = [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
                    return [NSString stringWithFormat:@"\"%@\"", escaped];
                };

                NSString *prompt = escape(entry[@"prompt"]);
                NSString *response = escape(entry[@"response"]);
                NSString *model = escape(entry[@"model"]);
                NSString *temp = escape([NSString stringWithFormat:@"%@", entry[@"temperature"] ?: @""]);
                NSString *max = escape([NSString stringWithFormat:@"%@", entry[@"max_tokens"] ?: @""]);

                // タブ区切り＋行末改行
                NSString *line = [NSString stringWithFormat:@"%@\t%@\t%@\t%@\t%@\n",
                                  prompt, response, model, temp, max];
                [output appendString:line];
            }

            // BOM付きUTF-8（Excel文字化け対策）
            NSURL *url = panel.URL;
            NSData *bom = [@"\uFEFF" dataUsingEncoding:NSUTF8StringEncoding];
            NSData *data = [output dataUsingEncoding:NSUTF8StringEncoding];
            NSMutableData *finalData = [NSMutableData dataWithData:bom];
            [finalData appendData:data];

            NSError *error = nil;
            BOOL success = [finalData writeToURL:url options:NSDataWritingAtomic error:&error];

            if (success) {
                NSLog(@"✅ 書き出し成功: %@", url.path);
            } else {
                NSLog(@"❌ 書き出し失敗: %@", error.localizedDescription);
            }
        }
    }];
}

- (IBAction)deleteSelectedHistory:(id)sender {
    NSInteger row = self.historyTable.selectedRow;
    if (row >= 0 && row < self.history.count) {
        [self.history removeObjectAtIndex:row];
        [self.historyTable reloadData];
    }
}

#pragma TableViewDataSource,Delegate########################

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.history.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSDictionary *entry = self.history[row];
    NSString *prompt = entry[@"prompt"];
    if (prompt.length > 40) {
        prompt = [[prompt substringToIndex:40] stringByAppendingString:@"..."];
    }
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

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
    if (obj.object == self.apiKeyField) {
        self.apiKeyField.stringValue = @"";
    }
}

@end
