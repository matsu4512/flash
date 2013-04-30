/**
 * 画像をぷるぷるするアプリ
 * できる事
 * 力の調整
 * ぷるぷるタイプの変更
 * 範囲指定
 * Webカメラ
 * 好きな画像を適用
 */

package 
{
	import com.adobe.utils.AGALMiniAssembler;
	import com.bit101.components.CheckBox;
	import com.bit101.components.Label;
	import com.bit101.components.PushButton;
	import com.bit101.components.RadioButton;
	import com.bit101.components.Slider;
	import com.bit101.components.Style;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.display.Stage3D;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DRenderMode;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.Texture;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Matrix;
	import flash.geom.Matrix3D;
	import flash.geom.Point;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	
	[SWF(width="800", height="600", frameRate="60", backgroundColor=0)]
	public class Stage3D_09 extends Sprite
	{
		private const WIDTH:Number = 500, HEIGHT:Number = 500;
		
		private var stage3D:Stage3D, context3D:Context3D;
		
		// 頂点シェーダ
		private const VERTEX_SHADER:String =
			"m44 op, va0, vc0 \n" +		
			"mov v0, va1 \n";			//ピクセルシェーダへ
		
		// ピクセルシェーダ
		private const FRAGMENT_SHADER:String =
			//テクスチャ情報の処理
			"tex oc, v0, fs0<2d, linear>";	//色情報の取得  v2:uv座標, fs0:画像データ
		
		//頂点データ
		private var indices:IndexBuffer3D, vertices:VertexBuffer3D, vertexData:Vector.<Number> = new Vector.<Number>(), indexData:Vector.<uint> = new Vector.<uint>();
		
		//ばね定数
		private const k:Number = 1.2;
		//減衰定数
		private const a:Number = 0.9;
		//この値が大きいほど、よりマウスに引き付けられる
		private const rep:Number = 100;
		//頂点の個数
		private var W:int = 30, H:int = 30;
		//頂点間の距離
		private var MASSW:Number, MASSH:Number;
		//頂点の位置情報と加わっている力を格納する配列
		private var forces:Vector.<Number> = new Vector.<Number>();
		
		//Webカメラ
		private var camera:Camera, video:Video = new Video(500,500);
		
		//テクスチャ用
		private var bmpd:BitmapData = new BitmapData(500, 500, false, 0);
		
		//ボタン
		private var cameraButton:PushButton, referenceButton:PushButton, regionSelectButton:PushButton, regionAllButton:PushButton, quakeButton:PushButton;
		private var attractionRadio:RadioButton, repulsionRadio:RadioButton;
		private var burstCheck:CheckBox;
		
		//範囲指定用
		private var regionBmpd:BitmapData = new BitmapData(500, 500, false, 0xFF0000);
		private var regionSp:Sprite = new Sprite();
		
		//状態
		private var mode:int = 0, cameraMode:Boolean=false;
		
		//ファイル関連
		private var ref:FileReference = new FileReference(), loader:Loader = new Loader();
		
		//設定用
		private var powerSlider:Slider;
		
		private var isSelectAll:Boolean = true;
		
		[Embed(source="prin.jpg")]
		private var Img:Class;
		
		public function Stage3D_09()
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;

			stage3D = this.stage.stage3Ds[0];
			
			//ボタンの生成
			cameraButton = new PushButton(this, 550, 50, "Use Camera", onCameraButtonClick);
			referenceButton = new PushButton(this, 550, 100, "Select Image", onReferenceButtonClick);
			regionSelectButton = new PushButton(this, 550, 220, "Select Start", onRegionSelectButtonClick);
			regionAllButton = new PushButton(this, 550, 270, "Select All", onRegionAllButton);
			quakeButton = new PushButton(this, 550, 570, "Puru", onPuru);
			quakeButton.visible = false;
			
			//サイズ調整
			cameraButton.scaleX = cameraButton.scaleY = 2;
			referenceButton.scaleX = referenceButton.scaleY = 2;
			regionSelectButton.scaleX = regionSelectButton.scaleY = 2;
			regionAllButton.scaleX = regionAllButton.scaleY = 2;
			quakeButton.scaleX = quakeButton.scaleY = 2;
			
			Style.fontSize = 16;
			//ラベルの生成
			new Label(this, 550, 10, "Select Resource");
			new Label(this, 550, 180, "Select Purupuru Region");
			new Label(this, 550, 330, "Power");
			new Label(this, 550, 440, "Select PuruPuru Type");
			
			//スライダーの生成
			powerSlider = new Slider(Slider.HORIZONTAL, this, 550, 370);
			powerSlider.minimum = 0;
			powerSlider.maximum = 1;
			powerSlider.width = 200;
			powerSlider.value = 0.15;

			Style.fontSize = 10;
			//ラジオボタンの生成
			attractionRadio = new RadioButton(this, 550, 490, "Attraction", true);
			repulsionRadio = new RadioButton(this, 550, 530, "Replusion", false);
			attractionRadio.groupName = repulsionRadio.groupName = "purupuru type";
			attractionRadio.scaleX = attractionRadio.scaleY = repulsionRadio.scaleX = repulsionRadio.scaleY = 1.5;
			
			//チェックボックスの生成
			burstCheck = new CheckBox(this, 550, 400, "Burst Mode");
			burstCheck.scaleX = burstCheck.scaleY = 1.5;
			
			ref.addEventListener(Event.SELECT, onSelect);
			ref.addEventListener(Event.COMPLETE, onRefComplete);
			
			stage3D.addEventListener(Event.CONTEXT3D_CREATE, onContext3DCreate);
			stage3D.requestContext3D(Context3DRenderMode.AUTO);
		}
		
		//頂点の初期化
		private function initVertex():void{
			MASSH = 2.0/(W-1);
			MASSW = 2.0/(H-1);
			
			//頂点の座標とuv座標の設定
			for(var i:int = 0; i < H; i++){
				for(var j:int = 0; j < W; j++){
					vertexData.push(
						j/(W-1)*2.0-1.0,	//x
						-(i/(H-1)*2.0-1.0),	//y
						0.0,				//z
						j/(W-1),			//u
						i/(H-1)				//v
					);
					forces.push(0, 0);
				}
			}
			
			//各三角形にインデックスを割り振る
			for(i = 0; i < H-1; i++){
				for(j = 0; j < W-1; j++){
					indexData.push(j+i*(W), (j+1)+i*(W), j+(i+1)*(W));
					indexData.push((j+1)+i*(W), j+(i+1)*(W), (j+1)+(i+1)*(W));
				}
			}
			
			// 5個(頂点座標(x,y,z)、uv座標(u,v))の値を持つ頂点用の頂点バッファを作成
			vertices = context3D.createVertexBuffer(W*H, 5);
			// 頂点データをアップロード
			vertices.uploadFromVector(vertexData, 0, W*H);
			// 最初の属性は座標の情報：Float型の数値が3つ　これを属性レジスタ0に入れる
			context3D.setVertexBufferAt(0, vertices, 0, Context3DVertexBufferFormat.FLOAT_3);
			// uv情報 Float型が2つ　これを属性レジスタ1に入れる
			context3D.setVertexBufferAt(1, vertices, 3, Context3DVertexBufferFormat.FLOAT_2);
			//インデックスバッファを作成
			indices = context3D.createIndexBuffer(indexData.length);
			//インデックス情報をアップロード
			indices.uploadFromVector(indexData, 0, indexData.length);
			
			//レジスタに登録
			context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, new Matrix3D());
			
			//テクスチャの初期化
			var bmp:Bitmap = new Img() as Bitmap;
			bmpd.draw(bmp, new Matrix(500/bmp.width, 0, 0, 500/bmp.height));
			createTexture(bmpd);
			
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
		}
		
		//BitmapDataからテクスチャを生成
		private function createTexture(bmpd:BitmapData):void{
			var texture:Texture = context3D.createTexture(512, 512, Context3DTextureFormat.BGRA, false);
			texture.uploadFromBitmapData(bmpd);
			//fs0に設定
			context3D.setTextureAt(0, texture);
		}
		
		//Context3Dの準備が整った
		private function onContext3DCreate(event:Event):void
		{
			context3D = Stage3D(event.target).context3D;
			
			context3D.configureBackBuffer(WIDTH, HEIGHT, 2, false);
			
			// 頂点シェーダをコンパイル;
			var vertexAssembly:AGALMiniAssembler = new AGALMiniAssembler();
			vertexAssembly.assemble(Context3DProgramType.VERTEX, VERTEX_SHADER);
			// ピクセルシェーダをコンパイル;
			var fragmentAssembly:AGALMiniAssembler = new AGALMiniAssembler();
			fragmentAssembly.assemble(Context3DProgramType.FRAGMENT, FRAGMENT_SHADER);
			
			var programPair:Program3D;
			// Program3Dのインスタンスを取得
			programPair = context3D.createProgram();
			// 頂点シェーダとピクセルシェーダのコードをGPUにアップロード
			programPair.upload(vertexAssembly.agalcode, fragmentAssembly.agalcode);
			// 使用するシェーダのペアを指定;
			context3D.setProgram(programPair);
			
			initVertex();
		}
		
		private function onEnterFrame(e:Event):void{
			//カメラからキャプチャ
			if(cameraMode){
				bmpd.draw(video);
				createTexture(bmpd);
			}			
			
			// drawTriangles()を呼ぶ前に必ずバッファをクリア;
			context3D.clear(0, 0, 0);
			
			//ぷるぷる
			if(regionBmpd.getPixel(mouseX, mouseY) == 0xFF0000) 
				if(attractionRadio.selected) doPuyoAttraction(mouseX/WIDTH*2.0-1.0, -(mouseY/HEIGHT*2.0-1.0), (burstCheck.selected?5000:powerSlider.value*2000));
				else doPuyoReplusion(mouseX/WIDTH*2.0-1.0, -(mouseY/HEIGHT*2.0-1.0), (burstCheck.selected?5000:powerSlider.value*2000));
			
			//頂点位置の更新
			for(var i:int = 0; i < H; i++){
				for(var j:int = 0; j < W; j++){
					var x:Number = vertexData[(i*W+j)*5], y:Number = vertexData[(i*W+j)*5+1];
					var fx:Number = forces[(i*W+j)*2], fy:Number = forces[(i*W+j)*2+1];
					fx = fx*a + (j*MASSW-1.0-x)*k;
					fy = fy*a + (-(i*MASSH-1.0)-y)*k;
					x += fx/10;
					y += fy/10;
					vertexData[(i*W+j)*5] = x;
					vertexData[(i*W+j)*5+1] = y;
					forces[(i*W+j)*2] = fx;
					forces[(i*W+j)*2+1] = fy;
				}
			}
			
			// 頂点データをアップロード
			vertices.uploadFromVector(vertexData, 0, W*H);
			// 3角形を全て描画する;
			context3D.drawTriangles(indices, 0, -1);
			//ビューポートに表示;
			context3D.present();
		}
		
		//指定した座標を中心にプルプルさせる。
		public function doPuyoAttraction(xx:Number, yy:Number, strength:Number):void{
			for(var i:int = 0; i < H; i++){
				for(var j:int = 0; j < W; j++){
					var x:Number = vertexData[(i*W+j)*5], y:Number = vertexData[(i*W+j)*5+1];
					var d:Number = new Point(x-xx,y-yy).length*100;
					//マウスの位置に引き寄せる
					forces[(i*W+j)*2] += ((xx - x)/(d/strength) + (j*MASSW - x)/rep)/30;
					forces[(i*W+j)*2+1] += ((yy - y)/(d/strength) + (i*MASSH - y)/rep)/30;
				}
			}
		}
		
		//指定した座標を中心にプルプルさせる。
		public function doPuyoReplusion(xx:Number, yy:Number, strength:Number):void{
			for(var i:int = 0; i < H; i++){
				for(var j:int = 0; j < W; j++){
					var x:Number = vertexData[(i*W+j)*5], y:Number = vertexData[(i*W+j)*5+1];
					var d:Number = new Point(x-xx,y-yy).length*100;
					//マウスの位置に引き寄せる
					forces[(i*W+j)*2] -= ((xx - x)/(d/strength) + (j*MASSW - x)/rep)/30;
					forces[(i*W+j)*2+1] -= ((yy - y)/(d/strength) + (i*MASSH - y)/rep)/30;
				}
			}
		}
		
		/*
			各ボタンが押された時の処理
		*/
		
		//Webカメラに切り替え
		private function onCameraButtonClick(e:MouseEvent):void{
			cameraMode = true;
			var texture:Texture = context3D.createTexture(512, 512, Context3DTextureFormat.BGRA, false);
			camera = Camera.getCamera("0");
			camera.setMode(500,500,30);
			video.attachCamera(camera);
			bmpd.draw(video);
			texture.uploadFromBitmapData(bmpd);
			context3D.setTextureAt(0, texture);
		}
		
		//画像をローカルからアップロード
		private function onReferenceButtonClick(e:MouseEvent):void{
			cameraMode = false;
			ref.browse([new FileFilter("画像を選択してください", "*.jpg;*.jpeg;*.png")]);
		}
		
		private function onSelect(e:Event):void{
			ref.load();
		}
		
		private function onRefComplete(e:Event):void{
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onComplete);
			loader.loadBytes(ref.data);
		}
		
		private function onComplete(e:Event):void{
			bmpd.draw(loader.content, new Matrix(500/loader.content.width,0,0,500/loader.content.height));
			createTexture(bmpd);
		}
		
		//範囲選択開始
		private function onRegionSelectButtonClick(e:MouseEvent):void{
			if(mode == 0){
				isSelectAll = false;
				quakeButton.enabled = cameraButton.enabled = referenceButton.enabled = regionAllButton.enabled = false;
				mode = 1;
				addChild(regionSp);
				regionBmpd.fillRect(regionBmpd.rect,0);
				regionSp.graphics.beginFill(0,0);
				regionSp.graphics.drawRect(0,0,500,500);
				regionSp.graphics.endFill();
				regionSp.addEventListener(MouseEvent.MOUSE_DOWN, onRegionMouseDown);
				regionSelectButton.label = "Select End";
			}
			else if(mode == 1){
				quakeButton.enabled = cameraButton.enabled = referenceButton.enabled = regionAllButton.enabled = true;
				regionSelectButton.label = "範囲選択";
				mode = 0;
				regionBmpd.draw(regionSp);
				regionSp.graphics.clear();
				regionSelectButton.label = "Select Start";
			}
		}
		
		private function onRegionMouseDown(e:MouseEvent):void{
			regionSp.removeEventListener(MouseEvent.MOUSE_DOWN, onRegionMouseDown);
			regionSp.addEventListener(MouseEvent.MOUSE_UP, onRegionMouseUp);
			regionSp.addEventListener(MouseEvent.MOUSE_MOVE, onRegionMouseMove);
			regionSp.graphics.beginFill(0xFF0000);
			regionSp.graphics.drawCircle(mouseX, mouseY, 8);
			regionSp.graphics.endFill();
		}
		
		private function onRegionMouseUp(e:MouseEvent):void{
			regionSp.addEventListener(MouseEvent.MOUSE_DOWN, onRegionMouseDown);
			regionSp.removeEventListener(MouseEvent.MOUSE_MOVE, onRegionMouseMove);
		}
		
		private function onRegionMouseMove(e:MouseEvent):void{
			regionSp.graphics.beginFill(0xFF0000);
			regionSp.graphics.drawCircle(mouseX, mouseY, 8);
			regionSp.graphics.endFill();
		}
		
		private function onRegionAllButton(e:MouseEvent):void{
			isSelectAll = true;
			regionBmpd.fillRect(regionBmpd.rect, 0xFF0000);
		}
		
		private function onPuru(e:MouseEvent):void{
			if(isSelectAll){
				for(var i:int = 0; i < 10; i++){
					var x:int = Math.random()*WIDTH, y:int = Math.random()*HEIGHT;
					if(attractionRadio.selected) doPuyoAttraction(x/WIDTH*2.0-1.0, -(y/HEIGHT*2.0-1.0), (burstCheck.selected?5000:powerSlider.value*2000));
					else doPuyoReplusion(x/WIDTH*2.0-1.0, -(y/HEIGHT*2.0-1.0), (burstCheck.selected?5000:powerSlider.value*2000));
				}
			}
			else{
				for(i = 0; i < WIDTH; i+=25){
					for(var j:int = 0; j < HEIGHT; j+=25){
						if(regionBmpd.getPixel(i, j) == 0xFF0000) 
							if(attractionRadio.selected) doPuyoAttraction(i/WIDTH*2.0-1.0, -(j/HEIGHT*2.0-1.0), (burstCheck.selected?5000:powerSlider.value*2000));
							else doPuyoReplusion(i/WIDTH*2.0-1.0, -(j/HEIGHT*2.0-1.0), (burstCheck.selected?5000:powerSlider.value*2000));
					}
				}
			}
		}
	}
}
