local View=dofile(ROOT..'/reframework/autorun/onimusha_issen/view.lua')
local checks=0
local function eq(actual,expected,message) checks=checks+1;assert(actual==expected,message) end
local depth,loads,opened=0,0,true
local api={get_default_font_size=function()return 16 end,load_font=function(path,size,ranges)
    loads=loads+1;eq(path,'onimusha_issen/IssenCJK.ttf','独立字体路径')
    eq(size,16,'跟随REFramework默认字号');eq(ranges[#ranges],0,'字形范围终止')
    return 17
end,push_font=function()depth=depth+1 end,pop_font=function()depth=depth-1 end,
calc_text_size=function(text)return{x=#text*6,y=18}end,
tree_node=function()return opened end,tree_pop=function()end,text=function()end}
local view=View.new(api)
eq(view:begin('test'),true,'打开菜单')
for _,item in ipairs(View.items) do eq(view:label(item):match('（[^）]+）$')~=nil,true,'中文（英文）格式') end
eq(view.metrics.loaded,true,'实际测量后记录字体就绪')
view:finish();eq(depth,0,'关闭菜单释放字体栈')
opened=false;eq(view:begin('test'),false,'折叠菜单')
eq(depth,0,'折叠后字体栈平衡');eq(loads,1,'字体仅加载一次')
api.load_font=function()return nil end
local failed=View.new(api)
opened=true;failed:begin('test')
eq(failed:label(View.items[1]),'Auto Issen','缺字体保留可读英文')
eq(failed.metrics.error~=nil,true,'缺字体错误可见')
failed:finish();eq(depth,0,'字体失败不污染栈')
local window_end,window_position,window_size=0,nil,nil
api.get_display_size=function()return{x=640,y=360}end
api.set_next_window_size=function(size)window_size=size end
api.set_next_window_pos=function(pos)window_position=pos end
api.begin_window=function()return true end
api.end_window=function()window_end=window_end+1 end
view.window_open=true
view:window(function()eq(depth,1,'独立设置窗口使用中文字体')end)
eq(window_position[2]+window_size[2]<=360,true,'设置窗口不超过屏幕底边')
eq(window_position[1]+window_size[1]<=640,true,'设置窗口不超过屏幕右边')
eq(depth,0,'设置窗口字体栈恢复')
local ok=pcall(function()view:window(function()error('drawing failure')end)end)
eq(ok,false,'渲染错误可见')
eq(depth,0,'渲染失败仍释放字体')
eq(window_end,2,'渲染失败仍结束窗口')
api.begin_window=function()return false end
view:window(function()error('关闭后不应渲染')end)
eq(view.window_open,false,'关闭按钮关闭独立窗口')
eq(window_end,3,'关闭后仍配对结束窗口')
return checks
