import KsApi
import Library
import Prelude
import UIKit

internal protocol DiscoveryFiltersViewControllerDelegate: class {
  func discoveryFilters(_ viewController: DiscoveryFiltersViewController, selectedRow: SelectableRow)
  func discoveryFiltersDidClose(_ viewController: DiscoveryFiltersViewController)
}

internal final class DiscoveryFiltersViewController: UIViewController, UITableViewDelegate {
  @IBOutlet fileprivate weak var closeButton: UIButton!
  @IBOutlet fileprivate weak var backgroundGradientView: GradientView!
  @IBOutlet fileprivate weak var filtersTableView: UITableView!

  fileprivate let dataSource = DiscoveryFiltersDataSource()
  fileprivate let viewModel: DiscoveryFiltersViewModelType = DiscoveryFiltersViewModel()

  internal weak var delegate: DiscoveryFiltersViewControllerDelegate?

  internal static func configuredWith(selectedRow: SelectableRow, categories: [KsApi.Category])
    -> DiscoveryFiltersViewController {

      let vc: DiscoveryFiltersViewController = Storyboard.Discovery.instantiate()
      vc.viewModel.inputs.configureWith(selectedRow: selectedRow, categories: categories)
      return vc
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.filtersTableView.dataSource = self.dataSource
    self.filtersTableView.delegate = self

    self.backgroundGradientView.startPoint = CGPoint(x: 0.0, y: 1.0)
    self.backgroundGradientView.endPoint = CGPoint(x: 1.0, y: 0.0)

    self.closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

    self.viewModel.inputs.viewDidLoad()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    self.viewModel.inputs.viewWillAppear()
  }

  internal override func bindViewModel() {
    super.bindViewModel()

    self.viewModel.outputs.animateInView
      .observeForUI()
      .observeValues { [weak self] in
        self?.animateIn(categoryId: $0)
    }

    self.viewModel.outputs.loadTopRows
      .observeForUI()
      .observeValues { [weak self] rows, id in
        self?.dataSource.load(topRows: rows, categoryId: id)
        self?.filtersTableView.reloadData()
    }

    self.viewModel.outputs.loadFavoriteRows
      .observeForUI()
      .observeValues { [weak self] rows, id in
        self?.dataSource.load(favoriteRows: rows, categoryId: id)
        self?.filtersTableView.reloadData()
    }

    self.viewModel.outputs.loadCategoryRows
      .observeForUI()
      .observeValues { [weak self] rows, id, selectedRowId in
        self?.dataSource.load(categoryRows: rows, categoryId: id)
        self?.filtersTableView.reloadData()
        if let indexPath = self?.dataSource.indexPath(forCategoryId: selectedRowId) {
          self?.filtersTableView.scrollToRow(at: indexPath as IndexPath, at: .top, animated: false)
        }
    }

    self.viewModel.outputs.notifyDelegateOfSelectedRow
      .observeForControllerAction()
      .observeValues { [weak self] selectedRow in
        guard let _self = self else { return }
        _self.animateOut()
        _self.delegate?.discoveryFilters(_self, selectedRow: selectedRow)
    }
  }

  internal override func bindStyles() {
    super.bindStyles()

    _ = self.filtersTableView
      |> UITableView.lens.rowHeight .~ UITableViewAutomaticDimension
      |> UITableView.lens.estimatedRowHeight .~ 55.0
      |> UITableView.lens.backgroundColor .~ .clear

    _ = self.closeButton
      |> UIButton.lens.accessibilityLabel %~ { _ in Strings.Closes_filters() }
  }

  internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if let expandableRow = self.dataSource.expandableRow(indexPath: indexPath) {
      self.viewModel.inputs.tapped(expandableRow: expandableRow)
    } else if let selectableRow = self.dataSource.selectableRow(indexPath: indexPath) {
      self.viewModel.inputs.tapped(selectableRow: selectableRow)
    }
  }

  internal func tableView(_ tableView: UITableView,
                          willDisplay cell: UITableViewCell,
                                          forRowAt indexPath: IndexPath) {

    if let cell = cell as? DiscoverySelectableRowCell {
      cell.willDisplay()
    } else if let cell = cell as? DiscoveryExpandableRowCell {
      cell.willDisplay()
    } else if let cell = cell as? DiscoveryExpandedSelectableRowCell {
      cell.willDisplay()

      if self.viewModel.outputs.shouldAnimateSelectableCell {
        let delay = indexPath.row - (self.dataSource.expandedRow() ?? 0)
        cell.animateIn(delayOffset: delay)
      }
    }
  }

  fileprivate func animateIn(categoryId: Int?) {
    let (startColor, endColor) = discoveryGradientColors(forCategoryId: categoryId)
    self.backgroundGradientView.setGradient([(startColor, 0.0), (endColor, 1.0)])
    self.backgroundGradientView.alpha = 0

    self.filtersTableView.frame.origin.y -= 20
    self.filtersTableView.alpha = 0

    UIView.animate(withDuration: 0.2,
                               delay: 0.0,
                               options: .curveEaseOut,
                               animations: {
                                self.backgroundGradientView.alpha = 1
                                },
                               completion: nil)

    UIView.animate(withDuration: 0.2,
                               delay: 0.2,
                               usingSpringWithDamping: 0.6,
                               initialSpringVelocity: 1.0,
                               options: .curveEaseOut, animations: {
                                self.filtersTableView.alpha = 1
                                self.filtersTableView.frame.origin.y += 20
                                },
                               completion: nil)
  }

  fileprivate func animateOut() {
    UIView.animate(withDuration: 0.1,
                               delay: 0.0,
                               options: .curveEaseOut,
                               animations: {
                                self.filtersTableView.alpha = 0
                                self.filtersTableView.frame.origin.y -= 20
                                },
                               completion: nil)

    UIView.animate(withDuration: 0.2,
                               delay: 0.1,
                               options: .curveEaseOut,
                               animations: {
                                self.backgroundGradientView.alpha = 0
                                self.filtersTableView.alpha = 0
                                },
                               completion: nil)
  }

  @objc fileprivate func closeButtonTapped(_ button: UIButton) {
    self.animateOut()
    self.delegate?.discoveryFiltersDidClose(self)
  }
}
