import 'package:coolapk_flutter/network/api/main.api.dart';
import 'package:coolapk_flutter/network/model/main_init.model.dart'
    as MainInitModel;
import 'package:coolapk_flutter/page/create_feed/create_feed.page.dart';
import 'package:coolapk_flutter/page/home/tab_page.dart';
import 'package:coolapk_flutter/util/anim_page_route.dart';
import 'package:coolapk_flutter/widget/common_error_widget.dart';
import 'package:coolapk_flutter/page/home/drawer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/**
 * 太烂了，不改了
 */

class HomePage extends StatefulWidget {
  HomePage({Key key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // 主页有两个tab
  // 前面是 服务器返回的tab config的 entityId, 后面是PageController
  Map<int, PageController> _controllerMap = {
    // 6390是首页，14468是数码页
    14468: PageController(initialPage: 0),
    6390: PageController(initialPage: 1),
  };

  // 来自服务器的配置数据
  // 包含了 启动图，以及主页两个页面(首页和数码) 的配置
  List<MainInitModel.MainInitModelData> _mainInitModelData;

  // 从服务器获取配置文件
  // 接口 /v6/main/init
  Future<bool> getMainInitModelData() async {
    if (_mainInitModelData != null) return true;
    await Future.delayed(Duration(milliseconds: 700));
    _mainInitModelData = (await MainApi.getInitConfig()).data;
    return true;
  }

  // 两个页面的配置
  List<MainInitModel.MainInitModelData> get _pageConfigs =>
      _mainInitModelData
          ?.where((element) =>
              element.entityTemplate == "configCard" &&
              element.entityType == "card")
          ?.toList() ??
      [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              // .push(ScaleInRoute(widget: CreateHtmlArticleFeedPage()));
              .push(ScaleInRoute(widget: CreateNormalFeedPage()));
        },
        child: Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: getMainInitModelData(),
        builder: (context, snap) {
          if (snap.hasError) {
            return CommonErrorWidget(
              error: snap.error,
              onRetry: () {
                // 这样就会触发重试
                setState(() {});
              },
            );
          }
          if (snap.hasData) {
            return _buildFrame();
          }
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  void _gotoTab(int pageEntityId, int page) {
    _controllerMap[pageEntityId].jumpToPage(page);
    // animateToPage 会导致经过的页面都会拉取数据...
  }

  void _refreshTab(int pageEntityId, int page) {
    try {
      _tabKeyMap[pageEntityId].currentState.refresh(page);
    } catch (err) {}
  }

  TabController _tabController; //

  @override
  void initState() {
    _tabController = TabController(vsync: this, length: 2);
    super.initState();
  }

  @override
  void dispose() {
    _controllerMap.forEach((key, value) {
      value.dispose();
    });
    _tabController.dispose();
    super.dispose();
  }

  GlobalKey<HomePageDrawerState> _homePageDrawerStateKey = GlobalKey();

  // 窗口框架
  Widget _buildFrame() {
    final width = MediaQuery.of(context).size.width;
    final tight = width < 550;
    final drawer = HomePageDrawer(
      // 先new一个
      key: _homePageDrawerStateKey,
      tabConfigs: _pageConfigs,
      gotoTab: _gotoTab,
      refreshTab: _refreshTab,
    );
    // 不收起drawer时用上
    final innerDrawer = <Widget>[
      Container(
        // width: width < 1000 ? 223 : 334,
        width: 233,
        child: drawer,
      ),
      const VerticalDivider(
        width: 2,
      ),
    ];
    return Provider.value(
      value: _tabController,
      child: Builder(
        builder: (context) => Scaffold(
          drawer: tight ? drawer : null, //
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.max,
            children: !tight ? innerDrawer : <Widget>[] // 不收起drawer时用上
              ..add(
                Expanded(
                  child: Center(child: _buildContent(context)), // 主要内容
                ),
              ),
          ),
        ),
      ),
    );
  }

  // 为了实现某个功能而写的垃圾代码...能用就行能用就行
  // key 是entityId value 是key
  Map<int, GlobalKey<__TabState>> _tabKeyMap = {};

  // 主要内容
  Widget _buildContent(final BuildContext context) {
    return TabBarView(
      controller: Provider.of<TabController>(context, listen: false),
      // 顶层controller
      children: _pageConfigs.map<Widget>((pageConfig) {
        GlobalKey<__TabState> _key = _tabKeyMap[pageConfig.entityId];
        if (_key == null)
          _key = _tabKeyMap[pageConfig.entityId] = GlobalKey<__TabState>();
        return _Tab(
          key: _key,
          configs: pageConfig.entities,
          controller: _controllerMap[pageConfig.entityId],
          onPageChanged: (newPage) {
            _homePageDrawerStateKey?.currentState?.onGotoTab(
                _pageConfigs.indexOf(pageConfig), (newPage).floor());
          },
        );
      }).toList(),
    );
  }
}

class _Tab extends StatefulWidget {
  final Function(dynamic) onPageChanged;
  final PageController controller;
  final List<MainInitModel.Entity> configs;
  _Tab({Key key, this.onPageChanged, this.controller, this.configs})
      : super(key: key);

  @override
  __TabState createState() => __TabState();
}

class __TabState extends State<_Tab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Map<int, GlobalKey<TabPageState>> _emm = {};

  refresh(int index) {
    _emm[index].currentState.refresh();
  }

  List<Widget> _pages;

  @override
  void initState() {
    _pages = widget.configs.map<Widget>((pageTab) {
      GlobalKey<TabPageState> _key = _emm[widget.configs.indexOf(pageTab)];
      if (_key == null)
        _key =
            _emm[widget.configs.indexOf(pageTab)] = GlobalKey<TabPageState>();
      return TabPage(
        key: _key,
        data: pageTab,
      );
    }).toList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PageView(
      onPageChanged: widget.onPageChanged,
      physics: BouncingScrollPhysics(),
      controller: widget.controller,
      children: _pages,
    );
  }
}
