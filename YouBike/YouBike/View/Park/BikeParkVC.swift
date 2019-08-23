//
//  BikeLocationVC.swift
//  YouBike
//
//  Created by LAU KIM FAI on 6/8/2019.
//  Copyright © 2019 Ricky Lau. All rights reserved.
//

import RxSwift
import RxCocoa
import UIKit
import RxBinding
import RxDataSources
import Pulley

class BikeParkVC: BaseVC {
    
    private var favouriteOnly = false
    convenience init(favouriteOnly: Bool, vm: ViewModel<BikeParkVM>) {
        self.init()
        self.favouriteOnly = favouriteOnly
        self.vm = vm
    }
    
    @IBOutlet weak var table: BaseTable!
    private lazy var btnRefresh = UIBarButtonItem(barButtonSystemItem: .refresh, target: nil, action: nil)
    
    override var isProcessing: [Driver<Bool>] { return [vm.isProcessing] }
    
    internal var vm: ViewModel<BikeParkVM>!
    private let adjust = ParkBookmarkVM.request().0
    lazy var currPark = BehaviorRelay<BikePark?>(value: nil)
    
    override func setupUI() {
        
        navigationItem.do{
            $0.title = favouriteOnly ? "最愛列表" : "YouBike 停車場列表"
            $0.rightBarButtonItems = [btnRefresh]
        }
        
        table.register(nib: BikeParkCell.self)
    }
    
    override func setupRX() {
        let fetch = Observable.merge(
            btnRefresh.rx.tap.asObservable(),
            table.refresh.asObservable(),
            .just(())
        )
        
        let output = vm.observe(.init(fetch: fetch))
        
        let filterObs = Observable
            .combineLatest(
                ParkBookmarkVM.request().1,
                Observable.just(favouriteOnly)
            )
            .map{ $0.1 ? $0.0 : nil }
        
        Observable
            .combineLatest(
                output.parks,
                filterObs
            )
            .map{ parks, filter -> [BikePark] in
                guard let filter = filter else { return parks }
                return parks.filter{ filter.contains($0.sno) }
            }
            .map{ locs -> [(String, [BikePark])] in
                locs
                    .group{ $0.sarea }
                    .sorted(by: { (l1, l2) -> Bool in
                        return l1.key > l2.key
                    })
                    .map{
                        ($0.key,
                         $0.value.sorted(by: { p1, p2 -> Bool in
                            return p1.ar > p2.ar
                         }))
                }
            }
            .map{ $0.map{ SectionModel(model: $0.0, items: $0.1) } }
            ~> table.rx.items(dataSource: BikeParkCell.dataSource(currPark: currPark.asObservable()))
            ~ bag
        
        if UIDevice.current.userInterfaceIdiom != .pad {
            table.rx.modelSelected(BikePark.self)
                .map{ [unowned self] in
                    PulleyViewController(
                        contentViewController: ParkLocationVC(park: $0, vm: self.vm),
                        drawerViewController: ParkDetailInfoVC(park: $0, vm: self.vm)
                    )
                        .then{ $0.drawerTopInset = 0 }
                }
                ~> rx.navigate
                ~ bag
        }
        
        guard favouriteOnly else { return }
        table.rx.modelDeleted(BikePark.self)
            .map{ $0.sno }
            ~> adjust
            ~ bag
    }
    
    
    
}
