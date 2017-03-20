# Behavior Tree
```txt
纯lua实现的一个简单的行为树
编写AI形式如下,可用思维导图制作后写个脚本导出
SEL:AI
    SEQ:去球场打球
        CON:不是情人节:isNotValentinesDay
        ACT:去球场:gotoCourt
        ACT:打球:playBall
    SEL:约会
        SEL:买花
            SEQ:回家拿钱
                CON:女友没花:hasnotFlowerGF
                CON:自己没花没带够钱:hasnotFlowerSelf:100
                ACT:走回家:goHome 
                ACT:拿钱:fetchMoney
            SEQ:去花店买花
                CON:女友没花:hasnotFlowerGF
                CON:自己没花:hasnotFlowerSelf
                ACT:走去花店:gotoFlowerShop
                ACT:买花:buyFlower
        SEQ:见女友
            ACT:去找女友:gotoGF
            CON:女友还在:isHereGF
            CON:女友没花:hasnotFlowerGF
            ACT:送花:giveFlower

使用方式如下,其中entity为人物model对象,上面定义的方法实现在model中
local tree = BehaviorTree.new(ai_string)
tree:behave(entity)
忘了说了,这是要每帧调用的
```


